-- ============================================================
-- 05_GEOGRAPHICAL_ANALYSIS.SQL
-- ============================================================
-- Purpose:
-- Examine the geographical distribution of reported seizure records,
-- country-level drug-class profiles, and regional/subregional patterns.
--
-- IMPORTANT INTERPRETATION NOTES
-- 1. The unit of analysis is an original seizure record, not a unique
--    seizure event, shipment, quantity, or person.
-- 2. Record counts reflect reporting activity and coverage as well as
--    enforcement and seizure activity. They are not measures of market
--    size, prevalence, consumption, or trafficking flows.
-- 3. The main comparative period is 2011-2025. The 2026 data are partial
--    (through June 2026) and are excluded from year-to-year comparisons.
-- 4. Country comparisons use ISO3 codes rather than country names.
-- 5. Drug classes not matched to the reference table are retained as
--    'Unclassified'; they are not silently dropped.
--
-- Dependencies:
--   fact_seizure, dim_country, dim_drug, vw_seizure_regional
--
-- Suggested execution:
--   Run each numbered query separately in DBeaver and save key outputs
--   for the corresponding research notes/report.
-- ============================================================


-- ============================================================
-- 1. OVERALL GEOGRAPHICAL DISTRIBUTION
-- ============================================================

-- 1.1 Countries with the largest cumulative number of records
--     (2011-2025).
--
-- This provides a descriptive overview of which countries account
-- for the largest share of records in the analysis period.
-- The share denominator is all records in the same period.

SELECT
    dc.ISO3,
    dc.country_name,
    COUNT(*) AS seizure_records,
    COUNT(DISTINCT f.source_year) AS reporting_years,
    MIN(f.source_year) AS first_reporting_year,
    MAX(f.source_year) AS last_reporting_year,
    COUNT(DISTINCT COALESCE(dd.drug_class, 'Unclassified'))
        AS drug_classes_reported,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS share_of_global_records
FROM fact_seizure f
JOIN dim_country dc
    ON f.country_key = dc.country_key
JOIN dim_drug dd
    ON f.drug_key = dd.drug_key
WHERE f.source_year BETWEEN 2011 AND 2025
GROUP BY
    dc.ISO3,
    dc.country_name
ORDER BY seizure_records DESC
LIMIT 20;


-- 1.2 Annual geographical concentration.
--
-- For each year, this query identifies:
--   - the leading country;
--   - the leading country's share of annual records;
--   - the combined share of the five largest reporting countries;
--   - the country-level Herfindahl-Hirschman Index (HHI).
--
-- HHI is calculated as the sum of squared country shares, expressed
-- as proportions. Higher values indicate that records are concentrated
-- among fewer countries. It is a descriptive concentration measure,
-- not a measure of market concentration.

WITH country_year AS (
    SELECT
        f.source_year AS year,
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS seizure_records
    FROM fact_seizure f
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.source_year,
        dc.ISO3,
        dc.country_name
),

ranked AS (
    SELECT
        *,
        SUM(seizure_records) OVER (
            PARTITION BY year
        ) AS annual_records,
        ROW_NUMBER() OVER (
            PARTITION BY year
            ORDER BY seizure_records DESC, ISO3
        ) AS country_rank
    FROM country_year
)

SELECT
    year,
    MAX(annual_records) AS total_records,
    COUNT(*) AS reporting_countries,
    MAX(
        CASE WHEN country_rank = 1
            THEN country_name
        END
    ) AS leading_country,
    ROUND(
        100.0 * MAX(
            CASE WHEN country_rank = 1
                THEN seizure_records
            END
        ) / MAX(annual_records),
        2
    ) AS leading_country_share_pct,
    ROUND(
        100.0 * SUM(
            CASE WHEN country_rank <= 5
                THEN seizure_records
                ELSE 0
            END
        ) / MAX(annual_records),
        2
    ) AS top5_share_pct,
    ROUND(
        SUM(
            POWER(
                1.0 * seizure_records / annual_records,
                2
            )
        ),
        4
    ) AS country_hhi
FROM ranked
GROUP BY year
ORDER BY year;


-- 1.3 How much does Colombia contribute to overall concentration?
--
-- Compare the country-level HHI calculated using all countries with
-- the HHI calculated after excluding Colombia and renormalizing the
-- remaining countries' shares.
--
-- This is a sensitivity analysis: it shows how strongly the overall
-- geographical concentration statistic depends on Colombia.

WITH country_year AS (
    SELECT
        f.source_year AS year,
        dc.ISO3,
        COUNT(*) AS records
    FROM fact_seizure f
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.source_year,
        dc.ISO3
),

country_shares AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY year
        ) AS total_records,
        SUM(
            CASE WHEN ISO3 <> 'COL'
                THEN records
                ELSE 0
            END
        ) OVER (
            PARTITION BY year
        ) AS records_without_colombia
    FROM country_year
),

concentration AS (
    SELECT
        year,
        MAX(total_records) AS total_records,
        SUM(
            CASE WHEN ISO3 = 'COL'
                THEN records
                ELSE 0
            END
        ) AS colombia_records,
        MAX(records_without_colombia) AS records_without_colombia,
        SUM(
            POWER(1.0 * records / total_records, 2)
        ) AS hhi_all,
        SUM(
            CASE WHEN ISO3 <> 'COL'
                THEN POWER(
                    1.0 * records / NULLIF(records_without_colombia, 0),
                    2
                )
                ELSE 0
            END
        ) AS hhi_without_colombia
    FROM country_shares
    GROUP BY year
)

SELECT
    year,
    total_records,
    colombia_records,
    ROUND(
        100.0 * colombia_records / NULLIF(total_records, 0),
        2
    ) AS colombia_share_pct,
    records_without_colombia,
    ROUND(hhi_all, 4) AS hhi_all,
    ROUND(hhi_without_colombia, 4) AS hhi_without_colombia
FROM concentration
ORDER BY year;


-- 1.4 Top five countries by year, excluding Colombia.
--
-- The denominator is the total number of records from countries other
-- than Colombia in that year. Therefore, share_pct sums to 100% across
-- all non-Colombia countries (subject to rounding).

WITH country_year AS (
    SELECT
        f.source_year AS year,
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS records
    FROM fact_seizure f
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE f.source_year BETWEEN 2011 AND 2025
      AND dc.ISO3 <> 'COL'
    GROUP BY
        f.source_year,
        dc.ISO3,
        dc.country_name
),

ranked_countries AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY year
        ) AS annual_records_without_colombia,
        ROW_NUMBER() OVER (
            PARTITION BY year
            ORDER BY records DESC, ISO3
        ) AS country_rank
    FROM country_year
)

SELECT
    year,
    country_rank,
    ISO3,
    country_name,
    records,
    ROUND(
        100.0 * records /
        NULLIF(annual_records_without_colombia, 0),
        2
    ) AS share_pct
FROM ranked_countries
WHERE country_rank <= 5
ORDER BY year, country_rank;


-- ============================================================
-- 2. COUNTRY-LEVEL DRUG-CLASS PROFILES
-- ============================================================

-- 2.1 Main drug classes in the ten countries with the most records.
--
-- The ten countries are selected using their total records over
-- 2011-2025. For each selected country, this query reports its five
-- most frequently recorded drug classes.
--
-- Percentages use the country's total records over the same period.

WITH country_totals AS (
    SELECT
        f.country_key,
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS total_records
    FROM fact_seizure f
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.country_key,
        dc.ISO3,
        dc.country_name
),

top_countries AS (
    SELECT *
    FROM country_totals
    ORDER BY total_records DESC
    LIMIT 10
),

country_drugs AS (
    SELECT
        f.country_key,
        COALESCE(dd.drug_class, 'Unclassified') AS drug_class,
        COUNT(*) AS records
    FROM fact_seizure f
    LEFT JOIN dim_drug dd
        ON f.drug_key = dd.drug_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.country_key,
        COALESCE(dd.drug_class, 'Unclassified')
),

ranked_classes AS (
    SELECT
        tc.ISO3,
        tc.country_name,
        tc.total_records,
        cd.drug_class,
        cd.records,
        ROUND(
            100.0 * cd.records / NULLIF(tc.total_records, 0),
            2
        ) AS share_pct,
        ROW_NUMBER() OVER (
            PARTITION BY tc.ISO3
            ORDER BY cd.records DESC, cd.drug_class
        ) AS class_rank
    FROM top_countries tc
    JOIN country_drugs cd
        ON tc.country_key = cd.country_key
)

SELECT
    ISO3,
    country_name,
    total_records,
    class_rank,
    drug_class,
    records,
    share_pct
FROM ranked_classes
WHERE class_rank <= 5
ORDER BY total_records DESC, ISO3, class_rank;


-- 2.2 Country specialization across drug classes.
--
-- HHI is calculated from each country's distribution of records
-- across drug classes. A higher class_hhi indicates that a larger
-- proportion of that country's records falls into a smaller number
-- of drug classes.
--
-- The minimum threshold of 1,000 records reduces the influence of
-- countries with very small numbers of observations. This threshold
-- is an analytical choice, not a statistical significance test.

WITH country_class AS (
    SELECT
        f.country_key,
        dc.ISO3,
        dc.country_name,
        COALESCE(dd.drug_class, 'Unclassified') AS drug_class,
        COUNT(*) AS records
    FROM fact_seizure f
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    LEFT JOIN dim_drug dd
        ON f.drug_key = dd.drug_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.country_key,
        dc.ISO3,
        dc.country_name,
        COALESCE(dd.drug_class, 'Unclassified')
),

country_shares AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY country_key
        ) AS total_records
    FROM country_class
),

country_hhi AS (
    SELECT
        country_key,
        ISO3,
        country_name,
        MAX(total_records) AS total_records,
        COUNT(*) AS number_of_classes,
        SUM(
            POWER(1.0 * records / NULLIF(total_records, 0), 2)
        ) AS class_hhi
    FROM country_shares
    GROUP BY
        country_key,
        ISO3,
        country_name
)

SELECT
    ISO3,
    country_name,
    total_records,
    number_of_classes,
    ROUND(class_hhi, 4) AS class_hhi
FROM country_hhi
WHERE total_records >= 1000
ORDER BY class_hhi DESC, ISO3;


-- 2.3 How do drug-class profiles change over time in selected countries?
--
-- This query follows five countries selected for their different
-- reporting profiles and geographical contexts.
-- Change the ISO3 list if a different country sample is required.
--
-- The output gives record counts by country, year, and drug class.
-- To compare profiles across countries or years, calculate shares
-- using each country's total records in that year as the denominator.

SELECT
    f.source_year AS year,
    dc.ISO3,
    dc.country_name,
    COALESCE(dd.drug_class, 'Unclassified') AS drug_class,
    COUNT(*) AS records
FROM fact_seizure f
JOIN dim_country dc
    ON f.country_key = dc.country_key
LEFT JOIN dim_drug dd
    ON f.drug_key = dd.drug_key
WHERE dc.ISO3 IN ('CAN', 'SWE', 'COL', 'NGA', 'RUS')
  AND f.source_year BETWEEN 2011 AND 2025
GROUP BY
    f.source_year,
    dc.ISO3,
    dc.country_name,
    COALESCE(dd.drug_class, 'Unclassified')
ORDER BY
    dc.ISO3,
    year,
    records DESC;


-- 2.4 Drug-class shares over time for the selected countries.
--
-- This companion query calculates percentages within each
-- country-year. It makes profiles easier to compare when the number
-- of records differs substantially across countries and years.

WITH country_year_class AS (
    SELECT
        f.source_year AS year,
        dc.ISO3,
        dc.country_name,
        COALESCE(dd.drug_class, 'Unclassified') AS drug_class,
        COUNT(*) AS records
    FROM fact_seizure f
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    LEFT JOIN dim_drug dd
        ON f.drug_key = dd.drug_key
    WHERE dc.ISO3 IN ('CAN', 'SWE', 'COL', 'NGA', 'RUS')
      AND f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.source_year,
        dc.ISO3,
        dc.country_name,
        COALESCE(dd.drug_class, 'Unclassified')
),

country_year_totals AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY ISO3, year
        ) AS country_year_records
    FROM country_year_class
)

SELECT
    year,
    ISO3,
    country_name,
    drug_class,
    records,
    ROUND(
        100.0 * records / NULLIF(country_year_records, 0),
        2
    ) AS share_within_country_year_pct
FROM country_year_totals
ORDER BY ISO3, year, records DESC;


-- ============================================================
-- 3. REGIONAL AND SUBREGIONAL PATTERNS
-- ============================================================

-- These queries use vw_seizure_regional, created in SQL 03.
-- The view standardizes selected subregion labels while preserving
-- the original source fields.
--
-- The regional view is based on ids_staging, so drug classification
-- is linked through the original drug name. The LEFT JOIN preserves
-- records that do not match dim_drug; these are labelled Unclassified.


-- 3.1 Overall distribution by region.
--
-- Counts records, distinct reporting countries, and distinct source
-- years represented in each region during 2011-2025.

SELECT
    Region,
    COUNT(*) AS total_records,
    COUNT(DISTINCT ISO3) AS reporting_countries,
    COUNT(DISTINCT source_year) AS years_covered
FROM vw_seizure_regional
WHERE source_year BETWEEN 2011 AND 2025
  AND Region IS NOT NULL
GROUP BY Region
ORDER BY total_records DESC;


-- 3.2 Overall distribution by subregion.

SELECT
    Region,
    standardized_subregion,
    COUNT(*) AS total_records,
    COUNT(DISTINCT ISO3) AS reporting_countries,
    COUNT(DISTINCT source_year) AS years_covered
FROM vw_seizure_regional
WHERE source_year BETWEEN 2011 AND 2025
  AND Region IS NOT NULL
  AND standardized_subregion IS NOT NULL
GROUP BY
    Region,
    standardized_subregion
ORDER BY total_records DESC;


-- 3.3 Drug-class composition by subregion.
--
-- Shares are calculated within each Region + subregion combination.
-- This denominator is important: the percentages describe the
-- composition of records within each subregion, not its share of
-- global records.

WITH subregion_classes AS (
    SELECT
        v.Region,
        v.standardized_subregion,
        COALESCE(dd.drug_class, 'Unclassified') AS drug_class,
        COUNT(*) AS records
    FROM vw_seizure_regional v
    LEFT JOIN dim_drug dd
        ON TRIM(v."Drug/Substance") = TRIM(dd.drug_name)
    WHERE v.source_year BETWEEN 2011 AND 2025
      AND v.Region IS NOT NULL
      AND v.standardized_subregion IS NOT NULL
    GROUP BY
        v.Region,
        v.standardized_subregion,
        COALESCE(dd.drug_class, 'Unclassified')
),

subregion_totals AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY Region, standardized_subregion
        ) AS total_records
    FROM subregion_classes
)

SELECT
    Region,
    standardized_subregion,
    drug_class,
    records,
    ROUND(
        100.0 * records / NULLIF(total_records, 0),
        2
    ) AS share_pct
FROM subregion_totals
ORDER BY
    Region,
    standardized_subregion,
    records DESC;


-- 3.4 Which countries contribute most to each subregion?
--
-- Country contribution is measured as a share of all records in the
-- corresponding subregion. ISO3 is the country identifier.
-- The country name is retrieved from dim_country to avoid relying
-- on potentially inconsistent source labels.

WITH country_subregion AS (
    SELECT
        v.Region,
        v.standardized_subregion,
        v.ISO3,
        dc.country_name,
        COUNT(*) AS records
    FROM vw_seizure_regional v
    LEFT JOIN dim_country dc
        ON v.ISO3 = dc.ISO3
    WHERE v.source_year BETWEEN 2011 AND 2025
      AND v.Region IS NOT NULL
      AND v.standardized_subregion IS NOT NULL
      AND v.ISO3 IS NOT NULL
    GROUP BY
        v.Region,
        v.standardized_subregion,
        v.ISO3,
        dc.country_name
),

country_shares AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY Region, standardized_subregion
        ) AS subregion_total,
        ROW_NUMBER() OVER (
            PARTITION BY Region, standardized_subregion
            ORDER BY records DESC, ISO3
        ) AS country_rank
    FROM country_subregion
)

SELECT
    Region,
    standardized_subregion,
    country_rank,
    ISO3,
    country_name,
    records,
    ROUND(
        100.0 * records / NULLIF(subregion_total, 0),
        2
    ) AS share_pct
FROM country_shares
WHERE country_rank <= 3
ORDER BY
    Region,
    standardized_subregion,
    country_rank;


-- 3.5 Robustness check: regional drug-class profiles excluding
--     the largest contributing country in each subregion.
--
-- Step 1: identify the country with the most records in each
--         Region + subregion.
-- Step 2: calculate the drug-class profile using all countries.
-- Step 3: recalculate the profile after excluding the leading country.
--
-- Comparing the two profiles helps assess whether an apparent
-- subregional drug-class pattern is broadly shared or is largely
-- driven by one country's reporting contribution.
--
-- This is a descriptive sensitivity analysis. It does not establish
-- that the remaining countries are representative of the subregion.

WITH country_totals AS (
    SELECT
        Region,
        standardized_subregion,
        ISO3,
        COUNT(*) AS country_records
    FROM vw_seizure_regional
    WHERE source_year BETWEEN 2011 AND 2025
      AND Region IS NOT NULL
      AND standardized_subregion IS NOT NULL
      AND ISO3 IS NOT NULL
    GROUP BY
        Region,
        standardized_subregion,
        ISO3
),

ranked_countries AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY Region, standardized_subregion
            ORDER BY country_records DESC, ISO3
        ) AS country_rank
    FROM country_totals
),

leading_countries AS (
    SELECT
        Region,
        standardized_subregion,
        ISO3 AS leading_country_ISO3,
        country_records AS leading_country_records
    FROM ranked_countries
    WHERE country_rank = 1
),

drug_profiles AS (
    SELECT
        v.Region,
        v.standardized_subregion,
        COALESCE(dd.drug_class, 'Unclassified') AS drug_class,
        COUNT(*) AS all_records,
        SUM(
            CASE
                WHEN v.ISO3 <> lc.leading_country_ISO3
                    THEN 1
                ELSE 0
            END
        ) AS records_excluding_leader
    FROM vw_seizure_regional v
    JOIN leading_countries lc
        ON v.Region = lc.Region
       AND v.standardized_subregion = lc.standardized_subregion
    LEFT JOIN dim_drug dd
        ON TRIM(v."Drug/Substance") = TRIM(dd.drug_name)
    WHERE v.source_year BETWEEN 2011 AND 2025
    GROUP BY
        v.Region,
        v.standardized_subregion,
        COALESCE(dd.drug_class, 'Unclassified')
),

profile_totals AS (
    SELECT
        *,
        SUM(all_records) OVER (
            PARTITION BY Region, standardized_subregion
        ) AS total_all_records,
        SUM(records_excluding_leader) OVER (
            PARTITION BY Region, standardized_subregion
        ) AS total_excluding_leader
    FROM drug_profiles
)

SELECT
    Region,
    standardized_subregion,
    drug_class,
    all_records,
    records_excluding_leader,
    ROUND(
        100.0 * all_records / NULLIF(total_all_records, 0),
        2
    ) AS original_share_pct,
    ROUND(
        100.0 * records_excluding_leader /
        NULLIF(total_excluding_leader, 0),
        2
    ) AS share_excluding_leader_pct
FROM profile_totals
ORDER BY
    Region,
    standardized_subregion,
    original_share_pct DESC;


-- ============================================================
-- 4. VALIDATION AND DIAGNOSTICS
-- ============================================================

-- 4.1 Confirm that the regional view contains the expected number
--     of records for the selected period.
--
-- The counts should match because vw_seizure_regional is a view
-- over ids_staging and should not add or remove rows.

SELECT
    (SELECT COUNT(*)
     FROM ids_staging
     WHERE source_year BETWEEN 2011 AND 2025
    ) AS staging_records,
    (SELECT COUNT(*)
     FROM vw_seizure_regional
     WHERE source_year BETWEEN 2011 AND 2025
    ) AS regional_view_records;


-- 4.2 Inspect missing geographical classifications.
--
-- These records are excluded from the regional/subregional
-- aggregation queries where the relevant field is required.
-- Review their size before interpreting regional coverage.

SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN ISO3 IS NULL THEN 1 ELSE 0 END)
        AS missing_iso3,
    SUM(CASE WHEN Region IS NULL THEN 1 ELSE 0 END)
        AS missing_region,
    SUM(CASE WHEN standardized_subregion IS NULL THEN 1 ELSE 0 END)
        AS missing_standardized_subregion
FROM vw_seizure_regional
WHERE source_year BETWEEN 2011 AND 2025;


-- 4.3 Inspect drug-name matching coverage in the regional view.
--
-- This is a diagnostic for the join used in Sections 3.3 and 3.5.
-- It shows how many records receive a drug class and how many remain
-- Unclassified after the LEFT JOIN.

SELECT
    CASE
        WHEN dd.drug_name IS NULL THEN 'Unclassified'
        ELSE COALESCE(dd.drug_class, 'Unclassified')
    END AS drug_class,
    COUNT(*) AS records
FROM vw_seizure_regional v
LEFT JOIN dim_drug dd
    ON TRIM(v."Drug/Substance") = TRIM(dd.drug_name)
WHERE v.source_year BETWEEN 2011 AND 2025
GROUP BY
    CASE
        WHEN dd.drug_name IS NULL THEN 'Unclassified'
        ELSE COALESCE(dd.drug_class, 'Unclassified')
    END
ORDER BY records DESC;


-- 4.4 Check how many countries are represented in each subregion.
--
-- Useful for interpreting the robustness analysis: a subregion
-- represented by very few countries requires particular caution
-- when excluding its largest contributor.

SELECT
    Region,
    standardized_subregion,
    COUNT(DISTINCT ISO3) AS reporting_countries,
    COUNT(*) AS records
FROM vw_seizure_regional
WHERE source_year BETWEEN 2011 AND 2025
  AND Region IS NOT NULL
  AND standardized_subregion IS NOT NULL
GROUP BY
    Region,
    standardized_subregion
ORDER BY reporting_countries, records DESC;


-- ============================================================
-- END OF SCRIPT
-- ============================================================
-- Substantive findings and interpretation in:
-- reports/05_geographical_analysis_conclusions.md
-- ============================================================
