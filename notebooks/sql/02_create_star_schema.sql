
-- ============================================================
-- 02_CREATE_STAR_SCHEMA.SQL
-- Purpose:
-- Build a relational star schema for the UNODC Individual
-- Drug Seizures dataset.
--
-- Source tables:
--   - ids_staging
--   - drug_reference
--
-- Target tables:
--   - dim_date
--   - dim_country
--   - dim_drug
--   - fact_seizure
--
-- Fact table grain:
-- One row represents one original source record.
--
-- IMPORTANT:
-- This is a REBUILD script. It drops and recreates the four
-- analytical tables. Back up your database or use a separate
-- test database before executing it.
--
-- The script does not modify ids_staging or drug_reference.
-- ============================================================


-- ============================================================
-- 1. PRE-BUILD VALIDATION
--
-- Check whether the source data is ready for the star schema.
-- Investigate any unexpected results before proceeding.
-- ============================================================


-- 1.1 Check staging and reference table sizes.

SELECT
    (SELECT COUNT(*) FROM ids_staging) AS staging_records,
    (SELECT COUNT(*) FROM drug_reference) AS reference_records;


-- 1.2 Check whether the drug reference contains conflicting
-- classifications for the same substance name.
--
-- The same drug name should not have multiple different
-- class/subgroup combinations if we want one row per drug
-- in dim_drug.

SELECT
    TRIM("Drug Name/Type") AS drug_name,
    COUNT(DISTINCT "Drug class/ group") AS distinct_classes,
    COUNT(DISTINCT "Drug Subgroup") AS distinct_subgroups

FROM drug_reference

WHERE "Drug Name/Type" IS NOT NULL
  AND TRIM("Drug Name/Type") <> ''

GROUP BY TRIM("Drug Name/Type")

HAVING
    COUNT(DISTINCT "Drug class/ group") > 1
    OR COUNT(DISTINCT "Drug Subgroup") > 1

ORDER BY drug_name;


-- 1.3 Check whether every staging substance can be matched
-- to the reference table.
--
-- Unmatched substances are allowed. They will remain in
-- dim_drug with NULL classifications.

SELECT
    COUNT(DISTINCT TRIM(s."Drug/Substance")) AS staging_substances,

    COUNT(DISTINCT TRIM(r."Drug Name/Type")) AS matched_substances

FROM ids_staging s

LEFT JOIN drug_reference r
    ON TRIM(s."Drug/Substance") = TRIM(r."Drug Name/Type");


-- 1.4 Check missing keys in the staging data.

SELECT
    COUNT(*) FILTER (
        WHERE "Seizure Date" IS NULL
    ) AS missing_dates,

    COUNT(*) FILTER (
        WHERE ISO3 IS NULL OR TRIM(ISO3) = ''
    ) AS missing_iso3,

    COUNT(*) FILTER (
        WHERE "Drug/Substance" IS NULL
           OR TRIM("Drug/Substance") = ''
    ) AS missing_drugs

FROM ids_staging;


-- ============================================================
-- 2. CREATE DIM_DATE
--
-- One row per calendar date.
--
-- date_key is the primary key.
-- The dimension covers the complete study period,
-- including the remaining dates of 2026.
-- ============================================================


-- Drop dependent fact table before rebuilding dimensions.

DROP TABLE IF EXISTS fact_seizure;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_country;
DROP TABLE IF EXISTS dim_drug;


-- Create the date dimension with its primary key.

CREATE TABLE dim_date (

    date_key DATE PRIMARY KEY,

    year BIGINT,
    month BIGINT,
    month_name VARCHAR,
    quarter BIGINT,
    day BIGINT,
    day_of_week BIGINT,
    day_name VARCHAR,
    is_weekend BOOLEAN

);


-- Populate the date dimension.

INSERT INTO dim_date

SELECT
    CAST(date_value AS DATE) AS date_key,

    YEAR(date_value) AS year,
    MONTH(date_value) AS month,
    MONTHNAME(date_value) AS month_name,
    QUARTER(date_value) AS quarter,
    DAY(date_value) AS day,
    DAYOFWEEK(date_value) AS day_of_week,
    DAYNAME(date_value) AS day_name,

    CASE
        WHEN DAYOFWEEK(date_value) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS is_weekend

FROM generate_series(
    DATE '2011-01-01',
    DATE '2026-12-31',
    INTERVAL 1 DAY
) AS dates(date_value);


-- Validate the date dimension.

SELECT
    COUNT(*) AS total_dates,
    MIN(date_key) AS first_date,
    MAX(date_key) AS last_date

FROM dim_date;


-- Inspect the first 10 dates.

SELECT *

FROM dim_date

ORDER BY date_key

LIMIT 10;


-- ============================================================
-- 3. CREATE DIM_COUNTRY
--
-- One row per ISO3 country code.
--
-- country_key is the primary key.
-- ISO3 is also unique.
--
-- Selected country names are standardized to avoid
-- inconsistent naming across source years.
-- ============================================================


-- 3.1 Inspect country-name variations before standardization.

SELECT
    ISO3,

    COUNT(DISTINCT "Country/Territory of Seizure")
        AS name_variations,

    STRING_AGG(
        DISTINCT "Country/Territory of Seizure",
        ' | '
    ) AS country_names

FROM ids_staging

WHERE ISO3 IS NOT NULL
  AND TRIM(ISO3) <> ''

GROUP BY ISO3

HAVING COUNT(DISTINCT "Country/Territory of Seizure") > 1

ORDER BY ISO3;


-- 3.2 Create the country dimension.

CREATE TABLE dim_country (

    country_key BIGINT PRIMARY KEY,
    ISO3 VARCHAR UNIQUE NOT NULL,
    country_name VARCHAR

);


-- 3.3 Populate the country dimension.
--
-- For countries with different source names, use a
-- standardized country name where explicitly specified.
-- For other countries, use the alphabetically first
-- non-empty name found in the source data.

INSERT INTO dim_country

WITH country_names AS (

    SELECT
        TRIM(ISO3) AS ISO3,

        CASE
            WHEN TRIM(ISO3) = 'CIV'
                THEN 'Côte d''Ivoire'

            WHEN TRIM(ISO3) = 'MAC'
                THEN 'Macao SAR, China'

            WHEN TRIM(ISO3) = 'NLD'
                THEN 'Netherlands'

            ELSE MIN(
                NULLIF(
                    TRIM("Country/Territory of Seizure"),
                    ''
                )
            )

        END AS country_name

    FROM ids_staging

    WHERE ISO3 IS NOT NULL
      AND TRIM(ISO3) <> ''

    GROUP BY TRIM(ISO3)

)

SELECT
    ROW_NUMBER() OVER (ORDER BY ISO3) AS country_key,
    ISO3,
    country_name

FROM country_names;


-- 3.4 Validate the country dimension.

SELECT
    COUNT(*) AS total_countries,
    COUNT(DISTINCT ISO3) AS unique_iso3,
    COUNT(DISTINCT country_key) AS unique_keys

FROM dim_country;


-- Inspect all countries.

SELECT *

FROM dim_country

ORDER BY ISO3;


-- ============================================================
-- 4. CREATE DIM_DRUG
--
-- One row per distinct substance in the seizure dataset.
--
-- drug_key is the primary key.
-- drug_name is unique.
--
-- Classification fields are obtained from drug_reference.
-- Substances without a reference match are retained with
-- NULL drug_class and drug_subgroup values.
-- ============================================================


-- 4.1 Create the drug dimension.

CREATE TABLE dim_drug (

    drug_key BIGINT PRIMARY KEY,
    drug_name VARCHAR UNIQUE NOT NULL,
    drug_class VARCHAR,
    drug_subgroup VARCHAR

);


-- 4.2 Populate the drug dimension.
--
-- TRIM is applied to both source and reference names.
-- DISTINCT prevents exact duplicate reference mappings
-- from multiplying rows in the join.
--
-- Run the conflicting-classification check in Section 1
-- before proceeding. Do not arbitrarily resolve conflicts.

INSERT INTO dim_drug

WITH all_drugs AS (

    SELECT DISTINCT
        TRIM("Drug/Substance") AS drug_name

    FROM ids_staging

    WHERE "Drug/Substance" IS NOT NULL
      AND TRIM("Drug/Substance") <> ''

),

reference_clean AS (

    SELECT DISTINCT
        TRIM("Drug Name/Type") AS drug_name,
        "Drug class/ group" AS drug_class,
        "Drug Subgroup" AS drug_subgroup

    FROM drug_reference

    WHERE "Drug Name/Type" IS NOT NULL
      AND TRIM("Drug Name/Type") <> ''

)

SELECT
    ROW_NUMBER() OVER (ORDER BY d.drug_name) AS drug_key,
    d.drug_name,
    r.drug_class,
    r.drug_subgroup

FROM all_drugs d

LEFT JOIN reference_clean r
    ON d.drug_name = r.drug_name;


-- 4.3 Check the number of classified and unclassified drugs.

SELECT
    COUNT(*) AS total_drugs,

    COUNT(DISTINCT drug_name) AS unique_drugs,

    COUNT(drug_class) AS classified_drugs,

    COUNT(*) - COUNT(drug_class) AS unclassified_drugs

FROM dim_drug;


-- 4.4 Calculate classification coverage.

SELECT
    COUNT(*) AS total_drugs,

    COUNT(drug_class) AS classified,

    ROUND(
        100.0 * COUNT(drug_class) / NULLIF(COUNT(*), 0),
        2
    ) AS classification_coverage_pct

FROM dim_drug;


-- 4.5 Inspect the first 50 substances.

SELECT *

FROM dim_drug

ORDER BY drug_class, drug_name

LIMIT 50;


-- ============================================================
-- 5. CREATE FACT_SEIZURE
--
-- One row per original source record.
--
-- seizure_key is a technical surrogate key.
-- It is NOT an official UNODC seizure-event identifier.
--
-- Foreign keys connect the fact table to the three dimensions.
--
-- Quantities retain their original measurement units.
-- Do not aggregate quantities across different units.
-- ============================================================


-- 5.1 Create the fact table with primary and foreign keys.

CREATE TABLE fact_seizure (

    seizure_key BIGINT PRIMARY KEY,

    date_key DATE,
    country_key BIGINT,
    drug_key BIGINT,

    quantity_seized DOUBLE,
    measurement_unit VARCHAR,

    city VARCHAR,
    administrative_region VARCHAR,
    physical_seizure_location VARCHAR,
    transportation_mode VARCHAR,

    source VARCHAR,
    reporting_channel VARCHAR,

    source_year BIGINT,
    source_file VARCHAR,
    source_sheet VARCHAR,

    is_zero_quantity BOOLEAN,

    FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key),

    FOREIGN KEY (country_key)
        REFERENCES dim_country(country_key),

    FOREIGN KEY (drug_key)
        REFERENCES dim_drug(drug_key)

);


-- 5.2 Populate the fact table.
--
-- LEFT JOIN preserves the original source rows.
-- Missing dimension matches will produce NULL foreign keys.
-- The validation queries below identify such cases.

INSERT INTO fact_seizure

SELECT
    ROW_NUMBER() OVER () AS seizure_key,

    dd.date_key,
    dc.country_key,
    dg.drug_key,

    s."Quantity Seized" AS quantity_seized,
    s."Measurement Unit" AS measurement_unit,

    s.City AS city,
    s."Administrative Region" AS administrative_region,
    s."Physical Seizure Location" AS physical_seizure_location,
    s."Trafficking Mode of Transportation" AS transportation_mode,

    s."Source" AS source,
    s."Reporting Channel" AS reporting_channel,

    s.source_year,
    s.source_file,
    s.source_sheet,

    CASE
        WHEN s."Quantity Seized" = 0 THEN TRUE
        ELSE FALSE
    END AS is_zero_quantity

FROM ids_staging s

LEFT JOIN dim_date dd
    ON CAST(s."Seizure Date" AS DATE) = dd.date_key

LEFT JOIN dim_country dc
    ON TRIM(s.ISO3) = dc.ISO3

LEFT JOIN dim_drug dg
    ON TRIM(s."Drug/Substance") = dg.drug_name;


-- ============================================================
-- 6. FINAL VALIDATION
--
-- Confirm that the fact table preserves the original
-- staging records and that all foreign keys are populated.
-- ============================================================


-- 6.1 Compare staging and fact table record counts.

SELECT
    (SELECT COUNT(*) FROM ids_staging) AS staging_records,

    (SELECT COUNT(*) FROM fact_seizure) AS fact_records,

    (SELECT COUNT(*) FROM fact_seizure)
      - (SELECT COUNT(*) FROM ids_staging) AS record_difference;


-- 6.2 Check missing dimension keys.

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE date_key IS NULL
    ) AS missing_date_keys,

    COUNT(*) FILTER (
        WHERE country_key IS NULL
    ) AS missing_country_keys,

    COUNT(*) FILTER (
        WHERE drug_key IS NULL
    ) AS missing_drug_keys,

    COUNT(*) FILTER (
        WHERE is_zero_quantity = TRUE
    ) AS zero_quantity_records

FROM fact_seizure;


-- 6.3 Verify uniqueness of technical keys.

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT seizure_key) AS unique_seizure_keys

FROM fact_seizure;


-- 6.4 Check the fact table distribution by source year.

SELECT
    source_year,
    COUNT(*) AS total_records,
    COUNT(DISTINCT country_key) AS reporting_countries,
    COUNT(DISTINCT drug_key) AS distinct_drugs

FROM fact_seizure

GROUP BY source_year

ORDER BY source_year;


-- 6.5 Verify primary and foreign key constraints.

SELECT
    table_name,
    constraint_type,
    constraint_column_names

FROM duckdb_constraints()

WHERE table_name IN (
    'dim_date',
    'dim_country',
    'dim_drug',
    'fact_seizure'
)

ORDER BY table_name, constraint_type;


-- ============================================================
-- END OF STAR SCHEMA CREATION
-- ============================================================
