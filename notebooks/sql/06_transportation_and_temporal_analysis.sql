-- ============================================================
-- 06_TRANSPORTATION_AND_TEMPORAL_ANALYSIS.SQL
-- ============================================================
-- Purpose:
-- Examine the availability and distribution of transportation-mode
-- information, and explore temporal patterns in seizure records.
--
-- IMPORTANT INTERPRETATION NOTES
-- 1. The unit of analysis is an original IDS source record.
-- 2. 'Data not available', NULL, and blank transportation values
--    indicate unavailable information. They must not be counted as
--    reported transportation modes.
-- 3. 'Not applicable/not transported' is kept separate from missing
--    information. It is not treated as a transportation mode.
-- 4. Transportation-mode patterns are descriptive only. Given the
--    high proportion of unavailable information and uneven country
--    coverage, they should not be interpreted as representative of
--    actual trafficking methods.
-- 5. The main temporal comparison covers source_year 2011-2025.
--    The 2026 data are partial and are excluded.
-- 6. source_year identifies the source workbook sheet/year. The
--    calendar year extracted from the seizure date is a different
--    concept. Use source_year for reporting-year comparisons and the
--    date dimension for month-of-year patterns.
--
-- Dependencies:
--   fact_seizure, dim_country, dim_drug, dim_date
--
-- Suggested execution:
--   Run each numbered query separately in DBeaver.
-- ============================================================


-- ============================================================
-- 1. TRANSPORTATION DATA COVERAGE
-- ============================================================

-- 1.1 Overall coverage.
-- Treat literal 'Data not available', NULL, and blank values as
-- unavailable. Keep 'Not applicable/not transported' separate.

WITH classified AS (
    SELECT
        CASE
            WHEN transportation_mode IS NULL
              OR TRIM(CAST(transportation_mode AS VARCHAR)) = ''
              OR LOWER(TRIM(CAST(transportation_mode AS VARCHAR)))
                    = 'data not available'
                THEN 'Unavailable'
            WHEN LOWER(TRIM(CAST(transportation_mode AS VARCHAR)))
                    = 'not applicable/not transported'
                THEN 'Not applicable'
            ELSE 'Reported transportation mode'
        END AS transportation_status
    FROM fact_seizure
    WHERE source_year BETWEEN 2011 AND 2025
)
SELECT
    transportation_status,
    COUNT(*) AS records,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS share_of_all_records_pct
FROM classified
GROUP BY transportation_status
ORDER BY records DESC;


-- 1.2 Transportation-mode categories as stored in the fact table.
-- Shares use all records in the selected period as denominator.

SELECT
    COALESCE(
        NULLIF(TRIM(CAST(transportation_mode AS VARCHAR)), ''),
        '[NULL / blank]'
    ) AS transportation_mode_category,
    COUNT(*) AS records,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS share_of_all_records_pct,
    COUNT(DISTINCT source_year) AS reporting_years,
    COUNT(DISTINCT country_key) AS reporting_countries
FROM fact_seizure
WHERE source_year BETWEEN 2011 AND 2025
GROUP BY
    COALESCE(
        NULLIF(TRIM(CAST(transportation_mode AS VARCHAR)), ''),
        '[NULL / blank]'
    )
ORDER BY records DESC;


-- 1.3 Availability of transportation information over time.

WITH annual_coverage AS (
    SELECT
        source_year,
        COUNT(*) AS total_records,
        SUM(
            CASE
                WHEN transportation_mode IS NULL
                  OR TRIM(CAST(transportation_mode AS VARCHAR)) = ''
                  OR LOWER(TRIM(CAST(transportation_mode AS VARCHAR)))
                        = 'data not available'
                    THEN 1
                ELSE 0
            END
        ) AS unavailable_records,
        SUM(
            CASE
                WHEN LOWER(TRIM(CAST(transportation_mode AS VARCHAR)))
                        = 'not applicable/not transported'
                    THEN 1
                ELSE 0
            END
        ) AS not_applicable_records
    FROM fact_seizure
    WHERE source_year BETWEEN 2011 AND 2025
    GROUP BY source_year
)
SELECT
    source_year,
    total_records,
    unavailable_records,
    total_records - unavailable_records - not_applicable_records
        AS reported_mode_records,
    not_applicable_records,
    ROUND(
        100.0 * unavailable_records / NULLIF(total_records, 0),
        2
    ) AS unavailable_pct,
    ROUND(
        100.0 * (
            total_records - unavailable_records - not_applicable_records
        ) / NULLIF(total_records, 0),
        2
    ) AS reported_mode_pct
FROM annual_coverage
ORDER BY source_year;


-- 1.4 Country-level availability of transportation information.
-- Country coverage denominator: all records for that country.
-- Minimum threshold: 1,000 records over 2011-2025.

WITH country_coverage AS (
    SELECT
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS total_records,
        SUM(
            CASE
                WHEN f.transportation_mode IS NULL
                  OR TRIM(CAST(f.transportation_mode AS VARCHAR)) = ''
                  OR LOWER(TRIM(CAST(f.transportation_mode AS VARCHAR)))
                        = 'data not available'
                    THEN 1
                ELSE 0
            END
        ) AS unavailable_records,
        SUM(
            CASE
                WHEN LOWER(TRIM(CAST(f.transportation_mode AS VARCHAR)))
                        = 'not applicable/not transported'
                    THEN 1
                ELSE 0
            END
        ) AS not_applicable_records
    FROM fact_seizure f
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY dc.ISO3, dc.country_name
)
SELECT
    ISO3,
    country_name,
    total_records,
    total_records - unavailable_records - not_applicable_records
        AS reported_mode_records,
    unavailable_records,
    not_applicable_records,
    ROUND(
        100.0 * (
            total_records - unavailable_records - not_applicable_records
        ) / NULLIF(total_records, 0),
        2
    ) AS reporting_coverage_pct
FROM country_coverage
WHERE total_records >= 1000
ORDER BY reporting_coverage_pct DESC, total_records DESC;


-- ============================================================
-- 2. DISTRIBUTION OF REPORTED TRANSPORTATION MODES
-- ============================================================

-- 2.1 Most frequently reported transportation modes.
-- Percentages are conditional on an actual mode being reported.

SELECT
    TRIM(CAST(transportation_mode AS VARCHAR)) AS transportation_mode,
    COUNT(*) AS records,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS share_of_reported_modes_pct,
    COUNT(DISTINCT country_key) AS reporting_countries,
    COUNT(DISTINCT source_year) AS reporting_years
FROM fact_seizure
WHERE source_year BETWEEN 2011 AND 2025
  AND transportation_mode IS NOT NULL
  AND TRIM(CAST(transportation_mode AS VARCHAR)) <> ''
  AND LOWER(TRIM(CAST(transportation_mode AS VARCHAR)))
        NOT IN (
            'data not available',
            'not applicable/not transported'
        )
GROUP BY TRIM(CAST(transportation_mode AS VARCHAR))
ORDER BY records DESC;


-- 2.2 Transportation mode by drug class.
-- Within-class percentages use only records with a reported mode.

WITH class_mode AS (
    SELECT
        COALESCE(dd.drug_class, 'Unclassified') AS drug_class,
        TRIM(CAST(f.transportation_mode AS VARCHAR))
            AS transportation_mode,
        COUNT(*) AS records
    FROM fact_seizure f
    LEFT JOIN dim_drug dd
        ON f.drug_key = dd.drug_key
    WHERE f.source_year BETWEEN 2011 AND 2025
      AND f.transportation_mode IS NOT NULL
      AND TRIM(CAST(f.transportation_mode AS VARCHAR)) <> ''
      AND LOWER(TRIM(CAST(f.transportation_mode AS VARCHAR)))
            NOT IN (
                'data not available',
                'not applicable/not transported'
            )
    GROUP BY
        COALESCE(dd.drug_class, 'Unclassified'),
        TRIM(CAST(f.transportation_mode AS VARCHAR))
),
class_mode_shares AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY drug_class
        ) AS reported_records_in_class
    FROM class_mode
)
SELECT
    drug_class,
    transportation_mode,
    records,
    ROUND(
        100.0 * records / NULLIF(reported_records_in_class, 0),
        2
    ) AS share_within_reported_class_pct
FROM class_mode_shares
ORDER BY drug_class, records DESC;


-- 2.3 Countries contributing most records for each
-- drug-class / transportation-mode combination.
-- Shares use the global total for that class-mode combination.

WITH country_mode AS (
    SELECT
        COALESCE(dd.drug_class, 'Unclassified') AS drug_class,
        TRIM(CAST(f.transportation_mode AS VARCHAR))
            AS transportation_mode,
        dc.ISO3,
        dc.country_name,
        COUNT(*) AS records
    FROM fact_seizure f
    LEFT JOIN dim_drug dd
        ON f.drug_key = dd.drug_key
    JOIN dim_country dc
        ON f.country_key = dc.country_key
    WHERE f.source_year BETWEEN 2011 AND 2025
      AND f.transportation_mode IS NOT NULL
      AND TRIM(CAST(f.transportation_mode AS VARCHAR)) <> ''
      AND LOWER(TRIM(CAST(f.transportation_mode AS VARCHAR)))
            NOT IN (
                'data not available',
                'not applicable/not transported'
            )
    GROUP BY
        COALESCE(dd.drug_class, 'Unclassified'),
        TRIM(CAST(f.transportation_mode AS VARCHAR)),
        dc.ISO3,
        dc.country_name
),
ranked AS (
    SELECT
        *,
        SUM(records) OVER (
            PARTITION BY drug_class, transportation_mode
        ) AS mode_total,
        ROW_NUMBER() OVER (
            PARTITION BY drug_class, transportation_mode
            ORDER BY records DESC, ISO3
        ) AS country_rank
    FROM country_mode
)
SELECT
    drug_class,
    transportation_mode,
    country_rank,
    ISO3,
    country_name,
    records,
    ROUND(
        100.0 * records / NULLIF(mode_total, 0),
        2
    ) AS share_pct
FROM ranked
WHERE country_rank <= 3
ORDER BY drug_class, transportation_mode, country_rank;


-- ============================================================
-- 3. TEMPORAL PATTERNS
-- ============================================================
-- Month is derived from the actual seizure date.
-- Annual reporting comparisons use source_year.


-- 3.1 Pooled distribution by calendar month.
-- Pooled shares are influenced by the volume of records in each year.

SELECT
    d.month AS month_number,
    d.month_name,
    COUNT(*) AS total_records,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS share_of_all_records_pct,
    COUNT(DISTINCT f.source_year) AS reporting_source_years
FROM fact_seizure f
JOIN dim_date d
    ON f.date_key = d.date_key
WHERE f.source_year BETWEEN 2011 AND 2025
GROUP BY d.month, d.month_name
ORDER BY d.month;


-- 3.2 Monthly record counts by source year.
-- Allows inspection of whether the monthly pattern is consistent.

SELECT
    f.source_year,
    d.month AS month_number,
    d.month_name,
    COUNT(*) AS total_records
FROM fact_seizure f
JOIN dim_date d
    ON f.date_key = d.date_key
WHERE f.source_year BETWEEN 2011 AND 2025
GROUP BY f.source_year, d.month, d.month_name
ORDER BY f.source_year, d.month;


-- 3.3 Normalize monthly counts within each source year.
-- annual_share_pct: share of that source year's records.
-- avg_records_per_calendar_day: adjusts for month length and leap years.

WITH monthly_counts AS (
    SELECT
        f.source_year,
        d.month AS month_number,
        d.month_name,
        COUNT(*) AS total_records,
        MAX(DAY(LAST_DAY(d.date_key))) AS days_in_month
    FROM fact_seizure f
    JOIN dim_date d
        ON f.date_key = d.date_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.source_year,
        d.month,
        d.month_name
),
monthly_shares AS (
    SELECT
        *,
        SUM(total_records) OVER (
            PARTITION BY source_year
        ) AS annual_records
    FROM monthly_counts
)
SELECT
    source_year,
    month_number,
    month_name,
    total_records,
    ROUND(
        100.0 * total_records / NULLIF(annual_records, 0),
        2
    ) AS annual_share_pct,
    ROUND(
        1.0 * total_records / NULLIF(days_in_month, 0),
        2
    ) AS avg_records_per_calendar_day
FROM monthly_shares
ORDER BY source_year, month_number;


-- 3.4 Average monthly shares across country-years.
-- Each eligible country-year receives equal weight.
-- Eligibility means at least one record in every calendar month;
-- it does not prove complete or continuous reporting.

WITH monthly_country_year AS (
    SELECT
        f.country_key,
        f.source_year,
        d.month AS month_number,
        d.month_name,
        COUNT(*) AS monthly_records
    FROM fact_seizure f
    JOIN dim_date d
        ON f.date_key = d.date_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY
        f.country_key,
        f.source_year,
        d.month,
        d.month_name
),
country_year_totals AS (
    SELECT
        country_key,
        source_year,
        SUM(monthly_records) AS annual_records,
        COUNT(DISTINCT month_number) AS observed_months
    FROM monthly_country_year
    GROUP BY country_key, source_year
),
eligible_country_years AS (
    SELECT
        country_key,
        source_year,
        annual_records
    FROM country_year_totals
    WHERE observed_months = 12
),
country_year_month_shares AS (
    SELECT
        m.month_number,
        m.month_name,
        m.country_key,
        m.source_year,
        100.0 * m.monthly_records /
            NULLIF(e.annual_records, 0) AS monthly_share_pct
    FROM monthly_country_year m
    JOIN eligible_country_years e
        ON m.country_key = e.country_key
       AND m.source_year = e.source_year
)
SELECT
    month_number,
    month_name,
    ROUND(AVG(monthly_share_pct), 2)
        AS avg_country_year_monthly_share_pct,
    COUNT(*) AS contributing_country_years
FROM country_year_month_shares
GROUP BY month_number, month_name
ORDER BY month_number;


-- ============================================================
-- 4. VALIDATION AND DIAGNOSTICS
-- ============================================================

-- 4.1 Inspect transportation categories requiring special treatment.

SELECT
    transportation_mode,
    COUNT(*) AS records
FROM fact_seizure
WHERE source_year BETWEEN 2011 AND 2025
GROUP BY transportation_mode
ORDER BY records DESC;


-- 4.2 Compare source_year with seizure calendar year.
-- They represent different concepts and should not be interchanged.

SELECT
    f.source_year,
    d.year AS seizure_calendar_year,
    COUNT(*) AS records
FROM fact_seizure f
JOIN dim_date d
    ON f.date_key = d.date_key
WHERE f.source_year BETWEEN 2011 AND 2025
GROUP BY f.source_year, d.year
HAVING f.source_year <> d.year
ORDER BY f.source_year, seizure_calendar_year;


-- 4.3 Number of country-years with different counts of observed months.

WITH observed_months AS (
    SELECT
        f.country_key,
        f.source_year,
        COUNT(DISTINCT d.month) AS observed_months
    FROM fact_seizure f
    JOIN dim_date d
        ON f.date_key = d.date_key
    WHERE f.source_year BETWEEN 2011 AND 2025
    GROUP BY f.country_key, f.source_year
)
SELECT
    observed_months,
    COUNT(*) AS country_years
FROM observed_months
GROUP BY observed_months
ORDER BY observed_months;


-- ============================================================
-- END OF SCRIPT
-- ============================================================
-- Store interpretation and findings in:
-- reports/06_transportation_and_temporal_analysis_conclusions.md
-- ============================================================
