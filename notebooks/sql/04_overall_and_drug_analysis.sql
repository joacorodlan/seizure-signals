-- ============================================================
-- 04. OVERALL AND DRUG ANALYSIS
-- ============================================================
--
-- Purpose:
-- Explore annual reporting patterns, changes in country
-- participation, drug-class composition, and selected
-- substance-specific patterns (opioids and cocaine).
--
-- IMPORTANT:
-- The unit of analysis is the reported seizure record.
-- Record counts do not measure quantities seized, market
-- prevalence, trafficking volumes, or trafficking routes.
--
-- Annual reporting analyses use fact_seizure.source_year,
-- which identifies the year of the original source sheet.
-- This is distinct from the calendar year of date_key.
--
-- 2026 contains partial-year data and is excluded from
-- year-on-year and annual composition comparisons below.
--
-- ============================================================
-- SECTION 1. OVERALL TRENDS
-- ============================================================


-- 1. How many seizure records are reported each year?
--    How many countries report, and how many records have
--    zero quantities?

SELECT
    f.source_year AS year,
    COUNT(*) AS seizure_records,
    COUNT(DISTINCT f.country_key) AS reporting_countries,
    SUM(CASE WHEN f.is_zero_quantity THEN 1 ELSE 0 END)
        AS zero_quantity_records
FROM fact_seizure f
GROUP BY f.source_year
ORDER BY f.source_year;


-- 2. Calculate year-on-year changes in the number of records.
--
-- 2026 is a partial year, so its percentage change is set
-- to NULL and should not be compared with full-year data.

WITH annual_counts AS (
    SELECT
        source_year AS year,
        COUNT(*) AS seizure_records
    FROM fact_seizure
    GROUP BY source_year
),

annual_changes AS (
    SELECT
        year,
        seizure_records,
        LAG(seizure_records) OVER (
            ORDER BY year
        ) AS previous_year_records
    FROM annual_counts
)

SELECT
    year,
    seizure_records,
    previous_year_records,
    CASE
        WHEN previous_year_records IS NULL OR year = 2026
            THEN NULL
        ELSE ROUND(
            100.0 * (seizure_records - previous_year_records)
            / NULLIF(previous_year_records, 0),
            2
        )
    END AS yoy_change_pct
FROM annual_changes
ORDER BY year;


-- 3. Investigate changes in reporting coverage.
--
-- Distinguish countries that continue reporting from
-- countries that start or stop appearing in the dataset.

WITH country_year AS (
    SELECT DISTINCT
        country_key,
        source_year AS year
    FROM fact_seizure
),

coverage_changes AS (
    SELECT
        current_year.year,
        COUNT(*) AS reporting_countries,
        SUM(
            CASE
                WHEN previous_year.country_key IS NOT NULL
                    THEN 1
                ELSE 0
            END
        ) AS continuing_countries,
        SUM(
            CASE
                WHEN previous_year.country_key IS NULL
                    THEN 1
                ELSE 0
            END
        ) AS new_countries
    FROM country_year current_year
    LEFT JOIN country_year previous_year
        ON current_year.country_key = previous_year.country_key
        AND current_year.year = previous_year.year + 1
    GROUP BY current_year.year
),

country_exits AS (
    SELECT
        previous_year.year + 1 AS year,
        COUNT(*) AS countries_no_longer_reporting
    FROM country_year previous_year
    LEFT JOIN country_year current_year
        ON previous_year.country_key = current_year.country_key
        AND current_year.year = previous_year.year + 1
    WHERE current_year.country_key IS NULL
    GROUP BY previous_year.year + 1
)

SELECT
    c.year,
    c.reporting_countries,
    c.continuing_countries,
    c.new_countries,
    COALESCE(e.countries_no_longer_reporting, 0)
        AS countries_no_longer_reporting
FROM coverage_changes c
LEFT JOIN country_exits e
    ON c.year = e.year
ORDER BY c.year;


-- 4. Separate reporting changes from changes in records
--    among countries that report in consecutive years.

WITH country_year_counts AS (
    SELECT
        source_year AS year,
        country_key,
        COUNT(*) AS seizure_records
    FROM fact_seizure
    GROUP BY source_year, country_key
),

yearly_comparison AS (
    SELECT
        current_year.year,
        COUNT(*) AS continuing_countries,
        SUM(previous_year.seizure_records)
            AS previous_records_same_countries,
        SUM(current_year.seizure_records)
            AS current_records_same_countries,
        SUM(current_year.seizure_records)
            - SUM(previous_year.seizure_records)
            AS change_same_countries
    FROM country_year_counts current_year
    INNER JOIN country_year_counts previous_year
        ON current_year.country_key = previous_year.country_key
        AND current_year.year = previous_year.year + 1
    GROUP BY current_year.year
)

SELECT
    year,
    continuing_countries,
    previous_records_same_countries,
    current_records_same_countries,
    change_same_countries,
    ROUND(
        100.0 * change_same_countries
        / NULLIF(previous_records_same_countries, 0),
        2
    ) AS change_same_countries_pct
FROM yearly_comparison
ORDER BY year;


-- 5. Identify which countries drive selected annual changes.
--
-- The selected comparisons are:
--   2013 vs 2014
--   2023 vs 2024
--   2024 vs 2025
--
-- Countries are ranked by the absolute change in records.
-- This captures both the largest increases and decreases.

WITH country_year_counts AS (
    SELECT
        source_year AS year,
        country_key,
        COUNT(*) AS seizure_records
    FROM fact_seizure
    GROUP BY source_year, country_key
),

year_pairs AS (
    SELECT *
    FROM (VALUES
        (2013, 2014),
        (2023, 2024),
        (2024, 2025)
    ) AS t(previous_year, current_year)
),

country_comparison AS (
    SELECT
        yp.previous_year,
        yp.current_year,
        dc.ISO3,
        dc.country_name,
        COALESCE(p.seizure_records, 0) AS previous_records,
        COALESCE(c.seizure_records, 0) AS current_records,
        COALESCE(c.seizure_records, 0)
            - COALESCE(p.seizure_records, 0) AS change_records,
        CASE
            WHEN p.country_key IS NULL THEN 'New'
            WHEN c.country_key IS NULL THEN 'Exited'
            ELSE 'Continuing'
        END AS participation_status
    FROM year_pairs yp
    CROSS JOIN dim_country dc
    LEFT JOIN country_year_counts p
        ON dc.country_key = p.country_key
        AND yp.previous_year = p.year
    LEFT JOIN country_year_counts c
        ON dc.country_key = c.country_key
        AND yp.current_year = c.year
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY previous_year, current_year
            ORDER BY ABS(change_records) DESC
        ) AS rank_change
    FROM country_comparison
)

SELECT
    previous_year,
    current_year,
    ISO3,
    country_name,
    previous_records,
    current_records,
    change_records,
    participation_status
FROM ranked
WHERE rank_change <= 10
ORDER BY previous_year, current_year, rank_change;


-- 6. Compare drug composition in selected country-years.
--
-- Colombia: 2013 and 2014
-- Sweden:   2023 and 2024
--
-- The percentage is calculated within each country-year.

WITH drug_counts AS (
    SELECT
        dc.ISO3,
        dc.country_name,
        f.source_year AS year,
        dg.drug_name,
        dg.drug_class,
        COUNT(*) AS seizure_records
    FROM fact_seizure f
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    JOIN dim_drug dg
        ON f.drug_key = dg.drug_key
    WHERE
        (dc.ISO3 = 'COL' AND f.source_year IN (2013, 2014))
        OR
        (dc.ISO3 = 'SWE' AND f.source_year IN (2023, 2024))
    GROUP BY
        dc.ISO3,
        dc.country_name,
        f.source_year,
        dg.drug_name,
        dg.drug_class
),

ranked AS (
    SELECT
        *,
        SUM(seizure_records) OVER (
            PARTITION BY ISO3, year
        ) AS total_records,
        ROW_NUMBER() OVER (
            PARTITION BY ISO3, year
            ORDER BY seizure_records DESC
        ) AS drug_rank
    FROM drug_counts
)

SELECT
    ISO3,
    country_name,
    year,
    drug_rank,
    drug_name,
    drug_class,
    seizure_records,
    ROUND(
        100.0 * seizure_records / NULLIF(total_records, 0),
        2
    ) AS percentage_of_country_records
FROM ranked
WHERE drug_rank <= 10
ORDER BY ISO3, year, drug_rank;


-- 7. Did the reporting process change?
--
-- 7a. Reporting channel by country and year.

SELECT
    dc.ISO3,
    dc.country_name,
    f.source_year AS year,
    f.reporting_channel,
    COUNT(*) AS seizure_records,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (
            PARTITION BY dc.ISO3, f.source_year
        ),
        2
    ) AS percentage
FROM fact_seizure f
JOIN dim_country dc
    ON f.country_key = dc.country_key
WHERE
    (dc.ISO3 = 'COL' AND f.source_year IN (2013, 2014))
    OR
    (dc.ISO3 = 'SWE' AND f.source_year IN (2023, 2024))
GROUP BY
    dc.ISO3,
    dc.country_name,
    f.source_year,
    f.reporting_channel
ORDER BY
    dc.ISO3,
    year,
    seizure_records DESC;


-- 7b. Source distribution by country and year.

SELECT
    dc.ISO3,
    dc.country_name,
    f.source_year AS year,
    f.source,
    COUNT(*) AS seizure_records
FROM fact_seizure f
JOIN dim_country dc
    ON f.country_key = dc.country_key
WHERE
    (dc.ISO3 = 'COL' AND f.source_year IN (2013, 2014))
    OR
    (dc.ISO3 = 'SWE' AND f.source_year IN (2023, 2024))
GROUP BY
    dc.ISO3,
    dc.country_name,
    f.source_year,
    f.source
ORDER BY
    dc.ISO3,
    year,
    seizure_records DESC;


-- Conclusions to revisit after running the queries:
-- Reported seizure records vary considerably across years.
-- Country participation changes substantially, particularly after 2023.
-- Changes in participation do not fully explain the fluctuations.
-- Colombia's 2014 increase is concentrated in cannabis and cocaine-related records.
-- Sweden's 2024 decline affects multiple substances and warrants a data-completeness investigation.


-- ============================================================
-- SECTION 2. ANNUAL EVOLUTION OF DRUG CLASSES
-- ============================================================


-- 1. Annual evolution of drug classes.
--
-- This is the single annual drug-class composition query.
-- The denominator includes all records in each source year.
-- Unclassified records are retained as a separate category.
-- 2026 is excluded because it is a partial year.

WITH annual_class_counts AS (
    SELECT
        f.source_year AS year,
        COALESCE(dd.drug_class, 'Unclassified') AS drug_class,
        COUNT(*) AS total_records
    FROM fact_seizure f
    LEFT JOIN dim_drug dd
        ON f.drug_key = dd.drug_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.source_year,
        COALESCE(dd.drug_class, 'Unclassified')
)

SELECT
    year,
    drug_class,
    total_records,
    ROUND(
        100.0 * total_records
        / SUM(total_records) OVER (PARTITION BY year),
        2
    ) AS annual_share_pct
FROM annual_class_counts
ORDER BY year, total_records DESC;


-- Conclusions to revisit after running the query:
-- 1. Cannabis remains the largest category in most years.
-- 2. Cocaine's relative share declines over the longer term,
--    although there are substantial fluctuations.
-- 3. Amphetamine-type stimulants become more prominent from 2020 onward.
-- 4. Opioid shares fluctuate substantially across years.
-- 5. NPS remain a smaller category, but their share increases
--    in some of the more recent years.
--
-- These are descriptive patterns in reported records. They
-- should be interpreted alongside country reporting coverage
-- and changes in substance classification.


-- ============================================================
-- SECTION 3. DRUG-LEVEL ANALYSIS
-- ============================================================


-- 1. Most frequently reported substances.
--
-- This query covers all drug classes and ranks substances
-- by the number of records across the full dataset.
-- The percentage denominator is all fact records.

SELECT
    dg.drug_name,
    dg.drug_class,
    COUNT(*) AS seizure_records,
    COUNT(DISTINCT f.country_key) AS reporting_countries,
    MIN(f.source_year) AS first_year,
    MAX(f.source_year) AS last_year,
    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(*) FROM fact_seizure),
        2
    ) AS share_of_all_records
FROM fact_seizure f
JOIN dim_drug dg
    ON f.drug_key = dg.drug_key
GROUP BY
    dg.drug_name,
    dg.drug_class
ORDER BY seizure_records DESC
LIMIT 20;


-- 2. Aggregate records by drug class.
--
-- The percentage denominator is all fact records.
-- Unclassified records are retained in the output.

SELECT
    COALESCE(dg.drug_class, 'Unclassified') AS drug_class,
    COUNT(*) AS seizure_records,
    COUNT(DISTINCT dg.drug_name) AS distinct_substances,
    COUNT(DISTINCT f.country_key) AS reporting_countries,
    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(*) FROM fact_seizure),
        2
    ) AS percentage_of_records
FROM fact_seizure f
LEFT JOIN dim_drug dg
    ON f.drug_key = dg.drug_key
GROUP BY COALESCE(dg.drug_class, 'Unclassified')
ORDER BY seizure_records DESC;


-- 3. Investigate the substances driving opioid trends.
--
-- Which substances explain changes in reported opioid records?
-- Examples of interest include fentanyl, tramadol and heroin.
--
-- The query is restricted to opioid records, so the percentage
-- represents each substance's share within all opioid records
-- for that source year.

SELECT
    f.source_year AS year,
    dg.drug_name,
    COUNT(*) AS seizure_records,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (PARTITION BY f.source_year),
        2
    ) AS share_within_opioids
FROM fact_seizure f
JOIN dim_drug dg
    ON f.drug_key = dg.drug_key
WHERE dg.drug_class = 'Opioids'
  AND f.source_year BETWEEN 2011 AND 2025
GROUP BY
    f.source_year,
    dg.drug_name
ORDER BY
    year,
    seizure_records DESC;


-- 4. Which countries drive the opioid trends?
--
-- Focus on heroin, fentanyl and tramadol.
-- The percentage is each country's share of all records for
-- that substance in the corresponding source year.
--
-- share_of_drug_records reflects the denominator: annual
-- records for the selected drug, not all global records.

WITH country_drug_counts AS (
    SELECT
        f.source_year AS year,
        dg.drug_name,
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS seizure_records
    FROM fact_seizure f
    JOIN dim_drug dg
        ON f.drug_key = dg.drug_key
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE dg.drug_name IN ('Heroin', 'Fentanyl', 'Tramadol')
      AND f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.source_year,
        dg.drug_name,
        dc.ISO3,
        dc.country_name
),

ranked AS (
    SELECT
        *,
        SUM(seizure_records) OVER (
            PARTITION BY year, drug_name
        ) AS annual_drug_records,
        ROW_NUMBER() OVER (
            PARTITION BY year, drug_name
            ORDER BY seizure_records DESC
        ) AS country_rank
    FROM country_drug_counts
)

SELECT
    year,
    drug_name,
    country_rank,
    ISO3,
    country_name,
    seizure_records,
    ROUND(
        100.0 * seizure_records / NULLIF(annual_drug_records, 0),
        2
    ) AS share_of_drug_records
FROM ranked
WHERE country_rank <= 5
ORDER BY year, drug_name, country_rank;


-- 5. Measure geographical concentration for selected opioids.
--
-- The Herfindahl-Hirschman Index (HHI) is calculated from
-- each country's share of annual records for the substance.
-- Higher HHI values indicate greater concentration.
--
-- ISO3 is included in the country-level grouping to avoid
-- relying on country names alone.

WITH country_counts AS (
    SELECT
        f.source_year AS year,
        dg.drug_name,
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS records
    FROM fact_seizure f
    JOIN dim_drug dg
        ON f.drug_key = dg.drug_key
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE dg.drug_name IN ('Heroin', 'Fentanyl', 'Tramadol')
      AND f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.source_year,
        dg.drug_name,
        dc.ISO3,
        dc.country_name
),

country_shares AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY year, drug_name
        ) AS total_records,
        ROW_NUMBER() OVER (
            PARTITION BY year, drug_name
            ORDER BY records DESC
        ) AS country_rank
    FROM country_counts
),

annual_concentration AS (
    SELECT
        year,
        drug_name,
        MAX(total_records) AS total_records,
        COUNT(*) AS reporting_countries,
        MAX(
            CASE WHEN country_rank = 1 THEN records END
        ) AS top_country_records,
        SUM(
            CASE WHEN country_rank <= 5 THEN records ELSE 0 END
        ) AS top5_records,
        SUM(
            POWER(1.0 * records / total_records, 2)
        ) AS hhi
    FROM country_shares
    GROUP BY year, drug_name
)

SELECT
    year,
    drug_name,
    total_records,
    reporting_countries,
    ROUND(
        100.0 * top_country_records / NULLIF(total_records, 0),
        2
    ) AS top_country_share_pct,
    ROUND(
        100.0 * top5_records / NULLIF(total_records, 0),
        2
    ) AS top5_share_pct,
    ROUND(hhi, 4) AS hhi
FROM annual_concentration
ORDER BY drug_name, year;


-- 6. Investigate country reporting coverage for selected opioids.
--
-- This query places fentanyl, tramadol and opioid records
-- in the context of each country's total reporting volume.
-- This is useful for identifying possible reporting changes.

SELECT
    f.source_year AS year,
    dc.ISO3,
    dc.country_name,
    COUNT(*) AS all_seizure_records,
    COUNT(*) FILTER (
        WHERE dg.drug_name = 'Fentanyl'
    ) AS fentanyl_records,
    COUNT(*) FILTER (
        WHERE dg.drug_name = 'Tramadol'
    ) AS tramadol_records,
    COUNT(*) FILTER (
        WHERE dg.drug_class = 'Opioids'
    ) AS opioid_records
FROM fact_seizure f
JOIN dim_country dc
    ON f.country_key = dc.country_key
JOIN dim_drug dg
    ON f.drug_key = dg.drug_key
WHERE dc.ISO3 IN ('CAN', 'MEX', 'SWE', 'NGA')
  AND f.source_year BETWEEN 2018 AND 2025
GROUP BY
    f.source_year,
    dc.ISO3,
    dc.country_name
ORDER BY
    dc.country_name,
    year;


-- 7. Compare opioid composition within selected countries.
--
-- The denominator is the total number of opioid records
-- for each country and source year.

SELECT
    f.source_year AS year,
    dc.ISO3,
    dc.country_name,
    dg.drug_name,
    COUNT(*) AS seizure_records,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (
            PARTITION BY f.source_year, dc.ISO3
        ),
        2
    ) AS share_of_country_opioid_records
FROM fact_seizure f
JOIN dim_country dc
    ON f.country_key = dc.country_key
JOIN dim_drug dg
    ON f.drug_key = dg.drug_key
WHERE dc.ISO3 IN ('CAN', 'SWE', 'NGA')
  AND dg.drug_class = 'Opioids'
  AND f.source_year BETWEEN 2018 AND 2025
GROUP BY
    f.source_year,
    dc.ISO3,
    dc.country_name,
    dg.drug_name
ORDER BY
    dc.country_name,
    year,
    seizure_records DESC;


-- Conclusions to revisit after running the queries:
-- Fentanyl is highly geographically concentrated in the
-- reporting data. Changes in leading countries should be
-- interpreted alongside each country's overall reporting volume.
--
-- Tramadol records are concentrated in a limited number of
-- reporting countries, but the leading countries vary by year.
--
-- Country-level opioid profiles can differ substantially.
-- The relative prominence of tramadol, fentanyl, heroin and
-- other opioids should be assessed within each country's
-- reported opioid records.
--
-- Important methodological qualification:
-- These findings describe reported seizure records. They do
-- not measure drug-market prevalence, trafficking volumes,
-- quantities seized, or actual trafficking routes.


-- ============================================================
-- SECTION 4. COCAINE-SPECIFIC ANALYSIS
-- ============================================================


-- 1. Most frequently reported cocaine-type substances.
--
-- The percentage denominator is explicitly all records in
-- fact_seizure, so the share_of_all_records alias is accurate.

SELECT
    dg.drug_name,
    COUNT(*) AS seizure_records,
    COUNT(DISTINCT f.country_key) AS reporting_countries,
    MIN(f.source_year) AS first_year,
    MAX(f.source_year) AS last_year,
    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(*) FROM fact_seizure),
        2
    ) AS share_of_all_records
FROM fact_seizure f
JOIN dim_drug dg
    ON f.drug_key = dg.drug_key
WHERE dg.drug_class = 'Cocaine-type'
GROUP BY dg.drug_name
ORDER BY seizure_records DESC;


-- 2. Annual trends in reported cocaine-type substances.
--
-- The percentage denominator is all cocaine-type records
-- in the corresponding source year.
-- 2026 is excluded because it is a partial year.

SELECT
    f.source_year AS year,
    dg.drug_name,
    COUNT(*) AS seizure_records,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (PARTITION BY f.source_year),
        2
    ) AS share_of_cocaine_records
FROM fact_seizure f
JOIN dim_drug dg
    ON f.drug_key = dg.drug_key
WHERE dg.drug_class = 'Cocaine-type'
  AND f.source_year BETWEEN 2011 AND 2025
GROUP BY
    f.source_year,
    dg.drug_name
ORDER BY
    year,
    seizure_records DESC;


-- 2a. Investigate the 2025 change.
--
-- Identify the countries accounting for the largest number
-- of records for each cocaine-type substance in 2024 and 2025.
--
-- share_of_drug_records is each country's share of annual
-- records for that particular substance.

WITH country_drug_counts AS (
    SELECT
        f.source_year AS year,
        dg.drug_name,
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS seizure_records
    FROM fact_seizure f
    JOIN dim_drug dg
        ON f.drug_key = dg.drug_key
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE dg.drug_class = 'Cocaine-type'
      AND f.source_year IN (2024, 2025)
    GROUP BY
        f.source_year,
        dg.drug_name,
        dc.ISO3,
        dc.country_name
),

ranked AS (
    SELECT
        *,
        SUM(seizure_records) OVER (
            PARTITION BY year, drug_name
        ) AS annual_drug_records,
        ROW_NUMBER() OVER (
            PARTITION BY year, drug_name
            ORDER BY seizure_records DESC
        ) AS country_rank
    FROM country_drug_counts
)

SELECT
    year,
    drug_name,
    country_rank,
    ISO3,
    country_name,
    seizure_records,
    ROUND(
        100.0 * seizure_records / NULLIF(annual_drug_records, 0),
        2
    ) AS share_of_drug_records
FROM ranked
WHERE country_rank <= 10
ORDER BY
    drug_name,
    year,
    country_rank;


-- 2a.1. Validate the substance composition in selected countries.
--
-- Compare overall seizure records with selected cocaine
-- substance categories for 2024 and 2025.
-- ISO3 is included to identify countries unambiguously.

SELECT
    f.source_year AS year,
    dc.ISO3,
    dc.country_name,
    COUNT(*) AS all_seizure_records,
    COUNT(*) FILTER (
        WHERE dg.drug_class = 'Cocaine-type'
    ) AS cocaine_records,
    COUNT(*) FILTER (
        WHERE dg.drug_name =
            'Cocaine hydrochloride (HCl, powder cocaine)'
    ) AS powder_cocaine_records,
    COUNT(*) FILTER (
        WHERE dg.drug_name = 'Cocaine base'
    ) AS cocaine_base_records,
    COUNT(*) FILTER (
        WHERE dg.drug_name = 'Coca paste'
    ) AS coca_paste_records,
    COUNT(*) FILTER (
        WHERE dg.drug_name = 'Non-specified cocaine-type'
    ) AS unspecified_cocaine_records
FROM fact_seizure f
JOIN dim_country dc
    ON f.country_key = dc.country_key
JOIN dim_drug dg
    ON f.drug_key = dg.drug_key
WHERE dc.ISO3 IN (
    'ITA', 'COL', 'ECU', 'DZA', 'CZE',
    'MEX', 'PAN', 'NGA', 'CAN', 'VEN',
    'DNK', 'MAR'
)
  AND f.source_year IN (2024, 2025)
GROUP BY
    f.source_year,
    dc.ISO3,
    dc.country_name
ORDER BY
    dc.country_name,
    year;


-- 2b. How many countries report cocaine in each year?
--
-- Compare the number of countries reporting cocaine-type
-- records in 2024 and 2025, including countries that appear
-- in only one of the two years.

WITH country_year AS (
    SELECT
        f.source_year AS year,
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS cocaine_records
    FROM fact_seizure f
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    JOIN dim_drug dg
        ON f.drug_key = dg.drug_key
    WHERE dg.drug_class = 'Cocaine-type'
      AND f.source_year IN (2024, 2025)
    GROUP BY
        f.source_year,
        dc.ISO3,
        dc.country_name
),

country_comparison AS (
    SELECT
        ISO3,
        country_name,
        MAX(
            CASE WHEN year = 2024 THEN cocaine_records ELSE 0 END
        ) AS records_2024,
        MAX(
            CASE WHEN year = 2025 THEN cocaine_records ELSE 0 END
        ) AS records_2025
    FROM country_year
    GROUP BY ISO3, country_name
)

SELECT
    COUNT(*) FILTER (
        WHERE records_2024 > 0
    ) AS countries_2024,
    COUNT(*) FILTER (
        WHERE records_2025 > 0
    ) AS countries_2025,
    COUNT(*) FILTER (
        WHERE records_2024 > 0 AND records_2025 > 0
    ) AS countries_reporting_both,
    COUNT(*) FILTER (
        WHERE records_2024 > 0 AND records_2025 = 0
    ) AS countries_only_2024,
    COUNT(*) FILTER (
        WHERE records_2024 = 0 AND records_2025 > 0
    ) AS countries_only_2025
FROM country_comparison;


-- 3. Geographical concentration across the full period.
--
-- Calculate the annual concentration of reported cocaine
-- records by substance and country.
--
-- HHI is calculated as the sum of squared country shares.
-- ISO3 is included in the country-level grouping.

WITH country_counts AS (
    SELECT
        f.source_year AS year,
        dg.drug_name,
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS records
    FROM fact_seizure f
    JOIN dim_drug dg
        ON f.drug_key = dg.drug_key
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE dg.drug_class = 'Cocaine-type'
      AND f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.source_year,
        dg.drug_name,
        dc.ISO3,
        dc.country_name
),

country_shares AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY year, drug_name
        ) AS total_records,
        ROW_NUMBER() OVER (
            PARTITION BY year, drug_name
            ORDER BY records DESC
        ) AS country_rank
    FROM country_counts
)

SELECT
    year,
    drug_name,
    MAX(total_records) AS total_records,
    COUNT(*) AS reporting_countries,
    ROUND(
        100.0 * MAX(
            CASE WHEN country_rank = 1 THEN records END
        ) / NULLIF(MAX(total_records), 0),
        2
    ) AS top_country_share_pct,
    ROUND(
        100.0 * SUM(
            CASE WHEN country_rank <= 5 THEN records ELSE 0 END
        ) / NULLIF(MAX(total_records), 0),
        2
    ) AS top5_share_pct,
    ROUND(
        SUM(POWER(1.0 * records / total_records, 2)),
        4
    ) AS hhi
FROM country_shares
GROUP BY year, drug_name
ORDER BY drug_name, year;


-- Conclusions to revisit after running the queries:
-- Cocaine records are dominated by a small number of substance
-- categories, including coca paste, cocaine base,
-- non-specified cocaine and powder cocaine.
--
-- The composition of reported cocaine records changes over
-- time. The relative prominence of individual substances
-- should be interpreted alongside country participation
-- and changes in substance classification.
--
-- Geographical concentration varies by substance and year.
-- A high HHI indicates that reported records are concentrated
-- among a small number of reporting countries; it does not
-- establish the location or direction of trafficking routes.
--
-- The 2025 composition is a potential discontinuity and should
-- be interpreted alongside the number of countries reporting,
-- the overall reporting volume of individual countries, and
-- the substance categories they use.
--
-- Important methodological qualification:
-- These findings describe reported seizure records, not
-- quantities seized, trafficking volumes, market prevalence,
-- or actual trafficking routes.


-- ============================================================
-- END OF SCRIPT
-- ============================================================
