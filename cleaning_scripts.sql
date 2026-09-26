-- ============================================================
-- Navy Contract Spending Analysis
-- Data Cleaning Scripts
-- Source: USAspending.gov, Department of the Navy Prime Awards, FY2025
-- ============================================================

USE navy_contracts

-- ------------------------------------------------------------
-- 1. INITIAL PROFILING
-- Confirm row count and check that date conversion worked
-- ------------------------------------------------------------

SELECT COUNT(*) AS total_rows FROM navy_contracts;

SELECT
    COUNT(*) AS total,
    SUM(action_date_clean IS NULL) AS null_action_date,
    SUM(start_date_clean IS NULL) AS null_start_date,
    SUM(end_date_clean IS NULL) AS null_end_date
FROM navy_contracts;


-- ------------------------------------------------------------
-- 2. DUPLICATE INVESTIGATION
-- A partial-column check (PIID + date + obligation) returns many
-- "duplicates" that are actually legitimate repeat contract
-- actions (mods, corrections, option exercises). Investigate a
-- sample before assuming they're bad data.
-- ------------------------------------------------------------

-- Partial-key check (returns false positives - for investigation only)
SELECT award_id_piid, action_date_clean, federal_action_obligation, COUNT(*)
FROM navy_contracts
GROUP BY award_id_piid, action_date_clean, federal_action_obligation
HAVING COUNT(*) > 1;

-- Inspect one PIID/date combination in full to see what's really going on
SELECT *
FROM navy_contracts
WHERE award_id_piid = 'N0003023C0100'
  AND action_date_clean = '2025-01-27';


-- ------------------------------------------------------------
-- 3. REMOVE TRUE DUPLICATES
-- Only rows identical across every column are removed, so
-- legitimate repeat actions on the same award are preserved.
-- ------------------------------------------------------------

CREATE TABLE navy_contracts_dedup AS
SELECT DISTINCT *
FROM navy_contracts;

-- Verify the row count dropped by a reasonable amount
SELECT COUNT(*) FROM navy_contracts;
SELECT COUNT(*) FROM navy_contracts_dedup;

-- Swap the deduped table into place
DROP TABLE navy_contracts;
RENAME TABLE navy_contracts_dedup TO navy_contracts;


-- ------------------------------------------------------------
-- 4. TEXT FIELD CLEANUP
-- Trim stray whitespace and strip embedded quote characters
-- that were breaking CSV export/row alignment downstream.
-- ------------------------------------------------------------

SET SQL_SAFE_UPDATES = 0;

UPDATE navy_contracts SET
    recipient_name           = TRIM(REPLACE(recipient_name, '"', '')),
    recipient_parent_name    = TRIM(REPLACE(recipient_parent_name, '"', '')),
    awarding_sub_agency_name = TRIM(REPLACE(awarding_sub_agency_name, '"', ''));

SET SQL_SAFE_UPDATES = 1;


-- ------------------------------------------------------------
-- 5. STANDARDIZE RECIPIENT NAME VARIANTS
-- Same company appearing under multiple name formats was
-- splitting totals across separate rows in aggregations.
-- ------------------------------------------------------------

SET SQL_SAFE_UPDATES = 0;

UPDATE navy_contracts SET recipient_name = 'LOCKHEED MARTIN CORPORATION'
WHERE recipient_name = 'LOCKHEED MARTIN CORP';

UPDATE navy_contracts SET recipient_name = 'NORTHROP GRUMMAN SYSTEMS CORPORATION'
WHERE recipient_name = 'NORTHROP GRUMMAN SYSTEMS CORP';

UPDATE navy_contracts SET recipient_name = 'HUNTINGTON INGALLS INCORPORATED'
WHERE recipient_name = 'HUNTINGTON INGALLS INC';

SET SQL_SAFE_UPDATES = 1;


-- ------------------------------------------------------------
-- 6. DATA QUALITY INVESTIGATION (not corrections)
-- Checked rather than blindly removed - both patterns turned
-- out to be legitimate contract activity, not data errors.
-- ------------------------------------------------------------

-- Negative obligation amounts (legitimate deobligations/corrections)
SELECT
    COUNT(*) AS negative_obligations,
    MIN(federal_action_obligation) AS most_negative,
    MAX(federal_action_obligation) AS least_negative
FROM navy_contracts
WHERE federal_action_obligation < 0;

-- Negative total award values (checked separately - these shouldn't
-- logically go negative the way obligations can)
SELECT COUNT(*) FROM navy_contracts WHERE current_total_value_of_award < 0;
SELECT COUNT(*) FROM navy_contracts WHERE potential_total_value_of_award < 0;

-- Pull the actual rows to review context before deciding how to treat them
SELECT award_id_piid, action_date_clean, federal_action_obligation,
       current_total_value_of_award, potential_total_value_of_award
FROM navy_contracts
WHERE potential_total_value_of_award < 0;


-- ------------------------------------------------------------
-- 7. DROP REDUNDANT RAW DATE COLUMNS
-- Once the *_clean date columns were confirmed accurate, the
-- original text-based date columns were no longer needed.
-- ------------------------------------------------------------

ALTER TABLE navy_contracts
    DROP COLUMN action_date,
    DROP COLUMN period_of_performance_start_date,
    DROP COLUMN period_of_performance_current_end_date;


-- ------------------------------------------------------------
-- 8. FINAL VERIFICATION
-- ------------------------------------------------------------

SELECT COUNT(*) AS final_row_count FROM navy_contracts;
-- Result: 41,552 clean rows, ready for the Power BI dashboard
