
-- ============================================================
-- 01_DATA_QUALITY.SQL
-- Project: Every Seizure Is a Signal
--
-- Purpose:
-- Assess the completeness, consistency and reliability
-- of the original UNODC Individual Drug Seizures dataset.
--
-- Source table: ids_staging
--
-- IMPORTANT:
-- These queries are diagnostic. They do not modify or delete
-- records from the original staging table.
-- ============================================================


-- ============================================================
-- 1. COMPLETENESS OF REQUIRED FIELDS
-- ============================================================

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE "Seizure Date" IS NULL
    ) AS missing_dates,

    COUNT(*) FILTER (
        WHERE ISO3 IS NULL OR TRIM(ISO3) = ''
    ) AS missing_country_codes,

    COUNT(*) FILTER (
        WHERE "Drug/Substance" IS NULL
           OR TRIM("Drug/Substance") = ''
    ) AS missing_drugs,

    COUNT(*) FILTER (
        WHERE "Quantity Seized" IS NULL
    ) AS missing_quantities

FROM ids_staging;

-- ============================================================
-- 2. DATE VALIDATION
-- Study period: 2011–2026
-- Note: 2026 is a partial year.
-- ============================================================

SELECT
    MIN("Seizure Date") AS earliest_date,
    MAX("Seizure Date") AS latest_date,

    COUNT(*) FILTER (
        WHERE "Seizure Date" < DATE '2011-01-01'
           OR "Seizure Date" >= DATE '2027-01-01'
    ) AS dates_outside_study_period

FROM ids_staging;


-- Check the distribution of records by source year.

SELECT
    source_year,
    COUNT(*) AS records,
    MIN("Seizure Date") AS earliest_date,
    MAX("Seizure Date") AS latest_date

FROM ids_staging

GROUP BY source_year
ORDER BY source_year;


-- ============================================================
-- 3. COUNTRY CODE VALIDATION
-- ISO3 codes should contain three uppercase letters.
-- ============================================================

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE ISO3 IS NULL
           OR NOT regexp_matches(TRIM(ISO3), '^[A-Z]{3}$')
    ) AS invalid_format_count,

    COUNT(DISTINCT ISO3) AS distinct_country_codes

FROM ids_staging;


-- Inspect country codes with inconsistent whitespace or casing.

SELECT
    ISO3,
    TRIM(ISO3) AS trimmed_iso3,
    COUNT(*) AS records

FROM ids_staging

WHERE ISO3 IS NOT NULL
  AND ISO3 <> TRIM(ISO3)

GROUP BY ISO3, TRIM(ISO3)
ORDER BY records DESC;


-- ============================================================
-- 4. QUANTITY VALIDATION
-- Zero quantities are retained for investigation.
-- Negative quantities are checked separately.
-- ============================================================

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE "Quantity Seized" = 0
    ) AS zero_quantities,

    COUNT(*) FILTER (
        WHERE "Quantity Seized" < 0
    ) AS negative_quantities,

    MIN("Quantity Seized") AS minimum_quantity,
    MAX("Quantity Seized") AS maximum_quantity

FROM ids_staging;


-- Inspect records with zero or negative quantities.

SELECT
    source_year,
    "Quantity Seized",
    "Measurement Unit",
    "Drug/Substance",
    "Country/Territory of Seizure",
    COUNT(*) AS records

FROM ids_staging

WHERE "Quantity Seized" <= 0

GROUP BY
    source_year,
    "Quantity Seized",
    "Measurement Unit",
    "Drug/Substance",
    "Country/Territory of Seizure"

ORDER BY source_year;


-- Distribution of zero quantities by year and measurement unit.

SELECT
    source_year,
    "Measurement Unit",
    COUNT(*) AS zero_records,
    COUNT(DISTINCT "Drug/Substance") AS distinct_drugs,
    COUNT(DISTINCT ISO3) AS distinct_countries

FROM ids_staging

WHERE "Quantity Seized" = 0

GROUP BY source_year, "Measurement Unit"

ORDER BY source_year, zero_records DESC;


-- ============================================================
-- 5. REPEATED RECORD COMBINATIONS
--
-- These checks identify records with identical values across
-- selected fields. They do NOT prove that records are duplicate
-- seizure events.
--
-- Do not automatically delete these records.
-- ============================================================

SELECT
    COUNT(*) AS total_records,

    COUNT(*) - COUNT(DISTINCT (
        "Seizure Date",
        ISO3,
        "Drug/Substance",
        "Quantity Seized",
        "Measurement Unit",
        City,
        "Administrative Region",
        "Physical Seizure Location",
        "Trafficking Mode of Transportation",
        "Source",
        "Reporting Channel",
        source_year,
        source_file,
        source_sheet
    )) AS repeated_combinations

FROM ids_staging;


-- Inspect the most frequent repeated combinations.

SELECT
    "Seizure Date",
    ISO3,
    "Drug/Substance",
    "Quantity Seized",
    "Measurement Unit",
    City,
    "Physical Seizure Location",
    COUNT(*) AS occurrences

FROM ids_staging

GROUP BY
    "Seizure Date",
    ISO3,
    "Drug/Substance",
    "Quantity Seized",
    "Measurement Unit",
    City,
    "Physical Seizure Location"

HAVING COUNT(*) > 1

ORDER BY occurrences DESC
LIMIT 100;


-- ============================================================
-- 6. COUNTRY AND SUBREGION CONSISTENCY
--
-- Investigate whether the same ISO3 code is associated with
-- multiple country names or subregions.
-- ============================================================

SELECT
    ISO3,
    Subregion,
    COUNT(*) AS records,
    MIN(source_year) AS first_year,
    MAX(source_year) AS last_year

FROM ids_staging

WHERE ISO3 IN ('AFG', 'AUT', 'CIV', 'MAC', 'NLD')

GROUP BY ISO3, Subregion

ORDER BY ISO3, records DESC;


-- Country names associated with selected ISO3 codes.

SELECT
    ISO3,
    "Country/Territory of Seizure" AS country_name,
    COUNT(*) AS records,
    MIN(source_year) AS first_year,
    MAX(source_year) AS last_year

FROM ids_staging

WHERE ISO3 IN ('CIV', 'MAC', 'NLD')

GROUP BY ISO3, country_name

ORDER BY ISO3, first_year;



-- ============================================================
-- 7. DRUG REFERENCE COVERAGE
--
-- Compare substances in the seizure dataset against the
-- drug reference table.
--
-- Staging column: "Drug/Substance"
-- Reference column: "Drug Name/Type"
-- ============================================================

-- Number of distinct substances in each table.

SELECT
    (
        SELECT COUNT(DISTINCT "Drug/Substance")
        FROM ids_staging
    ) AS staging_substances,

    (
        SELECT COUNT(DISTINCT "Drug Name/Type")
        FROM drug_reference
    ) AS reference_substances;


-- Substances in the seizure data that are absent
-- from the drug reference table.

SELECT DISTINCT
    s."Drug/Substance" AS unmatched_substance

FROM ids_staging s

LEFT JOIN drug_reference r
    ON TRIM(s."Drug/Substance") = TRIM(r."Drug Name/Type")

WHERE r."Drug Name/Type" IS NULL

ORDER BY unmatched_substance;


-- Substances in the reference table that do not appear
-- in the seizure data.

SELECT DISTINCT
    r."Drug Name/Type" AS unused_reference_substance

FROM drug_reference r

LEFT JOIN ids_staging s
    ON TRIM(r."Drug Name/Type") = TRIM(s."Drug/Substance")

WHERE s."Drug/Substance" IS NULL

ORDER BY unused_reference_substance;


-- ============================================================
-- END OF DATA QUALITY CHECKS
-- ============================================================
