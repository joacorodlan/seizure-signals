
-- ============================================================
-- 03_CREATE_REGIONAL_VIEW.SQL
-- Purpose:
-- Standardize geographical subregion labels to ensure
-- consistent regional classification in subsequent analyses.
--
-- Source table:
--   - ids_staging
--
-- Output view:
--   - vw_seizure_regional
--
-- IMPORTANT:
-- This script creates a VIEW, not a physical table.
-- The original staging records are not modified.
-- All original geographical values are preserved in the
-- original Subregion column.
-- ============================================================


-- ============================================================
-- 1. CREATE REGIONAL VIEW
--
-- The CASE statement standardizes known variations in
-- subregion naming conventions.
--
-- Original values are preserved in the Subregion column.
-- Standardized values are stored in standardized_subregion.
-- ============================================================

CREATE OR REPLACE VIEW vw_seizure_regional AS

SELECT
    *,

    CASE

        -- Standardize Eastern Europe labels.

        WHEN Subregion IN (
            'East Europe',
            'Eastern Europe'
        )
            THEN 'Eastern Europe'


        -- Standardize South-Eastern Europe labels.

        WHEN Subregion IN (
            'Southeast Europe',
            'South-Eastern Europe'
        )
            THEN 'South-Eastern Europe'


        -- Standardize Western and Central Europe labels.

        WHEN Subregion IN (
            'West and Central Europe',
            'Western and Central Europe'
        )
            THEN 'Western and Central Europe'


        -- Standardize Central Asia and Transcaucasia labels.

        WHEN Subregion IN (
            'Central Asia and Transcaucasia',
            'Central Asia and Transcaucasian countries'
        )
            THEN 'Central Asia and Transcaucasia'


        -- Standardize South-West Asia labels.

        WHEN Subregion IN (
            'South West Asia',
            'South-West Asia'
        )
            THEN 'South-West Asia'


        -- Preserve all other original subregion values.

        ELSE Subregion

    END AS standardized_subregion

FROM ids_staging;


-- ============================================================
-- 2. BASIC VIEW VALIDATION
--
-- Check that the view contains the same number of records
-- as the original staging table.
-- ============================================================

SELECT
    (SELECT COUNT(*) FROM ids_staging) AS staging_records,

    (SELECT COUNT(*) FROM vw_seizure_regional) AS view_records,

    (SELECT COUNT(*) FROM vw_seizure_regional)
      - (SELECT COUNT(*) FROM ids_staging) AS record_difference;


-- Inspect a sample of the resulting view.

SELECT *

FROM vw_seizure_regional

LIMIT 5;


-- ============================================================
-- 3. VALIDATE STANDARDIZED GEOGRAPHICAL CLASSIFICATIONS
--
-- Inspect the geographical hierarchy after standardization.
-- Record counts help identify the most represented
-- region/subregion combinations.
-- ============================================================

SELECT
    Region,
    standardized_subregion,
    COUNT(*) AS records,
    COUNT(DISTINCT ISO3) AS reporting_countries

FROM vw_seizure_regional

GROUP BY
    Region,
    standardized_subregion

ORDER BY
    Region,
    standardized_subregion;


-- ============================================================
-- 4. CHECK MISSING GEOGRAPHICAL CLASSIFICATIONS
--
-- Identify records with missing or blank geographical labels.
-- These records are not automatically removed.
-- ============================================================

SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE Region IS NULL OR TRIM(Region) = ''
    ) AS missing_regions,

    COUNT(*) FILTER (
        WHERE Subregion IS NULL OR TRIM(Subregion) = ''
    ) AS missing_subregions,

    COUNT(*) FILTER (
        WHERE standardized_subregion IS NULL
           OR TRIM(standardized_subregion) = ''
    ) AS missing_standardized_subregions

FROM vw_seizure_regional;


-- ============================================================
-- 5. INSPECT ORIGINAL LABELS AND THEIR STANDARDIZED VALUES
--
-- Useful for documenting exactly which transformations
-- have been applied.
-- ============================================================

SELECT
    Subregion AS original_subregion,
    standardized_subregion,
    COUNT(*) AS records

FROM vw_seizure_regional

GROUP BY
    Subregion,
    standardized_subregion

ORDER BY
    standardized_subregion,
    original_subregion;


-- ============================================================
-- END OF REGIONAL VIEW CREATION
-- ============================================================
