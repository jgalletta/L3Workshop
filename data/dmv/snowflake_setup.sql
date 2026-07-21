-- ============================================================================
-- DMV Wait-Times : Snowflake setup for real-time ingestion + Data Cloud
-- ============================================================================
-- Run top-to-bottom in a Snowsight worksheet (or via SnowSQL). Adjust the
-- warehouse/db/schema names to your conventions.
-- ============================================================================

USE WAREHOUSE SNOWFLAKE_LEARNING_WH;   -- auto-resumes; swap for your own if preferred

CREATE DATABASE IF NOT EXISTS DMV_OPS;
CREATE SCHEMA   IF NOT EXISTS DMV_OPS.RAW;      -- landing / streaming
CREATE SCHEMA   IF NOT EXISTS DMV_OPS.CORE;     -- modeled, query-serving
USE SCHEMA DMV_OPS.RAW;

-- ----------------------------------------------------------------------------
-- 1. RAW landing table  (append-only fact stream — the "first table")
-- ----------------------------------------------------------------------------
-- Every wait-time reading lands here, unmodified. Append-only, never updated.
-- This is what Data Cloud will pull from (or what your stream writes into).
CREATE TABLE IF NOT EXISTS RAW.WAIT_TIME_READING (
    READING_ID            STRING       NOT NULL,   -- natural key: office+svc+ts
    OFFICE_ID             STRING       NOT NULL,
    OFFICE_NAME           STRING,
    CITY                  STRING,
    REGION                STRING,
    NUM_WINDOWS           NUMBER(4,0),
    LATITUDE              FLOAT,
    LONGITUDE             FLOAT,
    SERVICE_TYPE_ID       STRING       NOT NULL,
    SERVICE_TYPE          STRING,
    APPOINTMENT_ELIGIBLE  BOOLEAN,
    OBSERVED_AT           TIMESTAMP_NTZ NOT NULL,   -- event time (the reading)
    WAIT_MINUTES          NUMBER(6,1),
    QUEUE_LENGTH          NUMBER(6,0),
    WINDOWS_SERVING       NUMBER(4,0),
    CONGESTION_STATUS     STRING,                   -- LOW / MODERATE / HIGH
    SOURCE                STRING,
    -- ingestion metadata (set on load, not from the file)
    LOADED_AT             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY (OBSERVED_AT, OFFICE_ID);   -- time-first clustering for range scans

-- ----------------------------------------------------------------------------
-- 2. File format + stage for the initial CSV load-from-file
-- ----------------------------------------------------------------------------
CREATE FILE FORMAT IF NOT EXISTS RAW.CSV_STD
    TYPE = CSV
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE;

CREATE STAGE IF NOT EXISTS RAW.DMV_STAGE
    FILE_FORMAT = RAW.CSV_STD;

-- >> In Snowsight: use "Load Data" on RAW.WAIT_TIME_READING and pick the CSV,
--    OR upload via SnowSQL then COPY:
--
--    PUT file:///.../dmv_wait_times.csv @RAW.DMV_STAGE AUTO_COMPRESS=TRUE;
--
-- Column order in the CSV matches the table, EXCEPT the CSV has no LOADED_AT.
COPY INTO RAW.WAIT_TIME_READING (
    READING_ID, OFFICE_ID, OFFICE_NAME, CITY, REGION, NUM_WINDOWS,
    LATITUDE, LONGITUDE, SERVICE_TYPE_ID, SERVICE_TYPE, APPOINTMENT_ELIGIBLE,
    OBSERVED_AT, WAIT_MINUTES, QUEUE_LENGTH, WINDOWS_SERVING,
    CONGESTION_STATUS, SOURCE
)
FROM @RAW.DMV_STAGE
FILE_FORMAT = RAW.CSV_STD
ON_ERROR = 'CONTINUE';

-- ----------------------------------------------------------------------------
-- 3. CORE serving view  (latest reading per office+service — the "live" state)
-- ----------------------------------------------------------------------------
-- Data Cloud can ingest the raw fact directly, but a "current state" view is
-- what appointment optimization actually reads. QUALIFY keeps one row per key.
CREATE OR REPLACE VIEW CORE.CURRENT_WAIT AS
SELECT *
FROM RAW.WAIT_TIME_READING
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY OFFICE_ID, SERVICE_TYPE_ID
    ORDER BY OBSERVED_AT DESC
) = 1;

-- ----------------------------------------------------------------------------
-- 4. (Optional) Data Cloud pull-friendly incremental view
-- ----------------------------------------------------------------------------
-- Data Cloud's Snowflake connector does incremental refresh on a monotonic
-- cursor column. Expose LOADED_AT so it only pulls new rows each run.
CREATE OR REPLACE VIEW CORE.WAIT_READING_CDC AS
SELECT * FROM RAW.WAIT_TIME_READING;   -- cursor = LOADED_AT (or OBSERVED_AT)

-- ----------------------------------------------------------------------------
-- 5. Sanity checks
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS total_rows,
       MIN(OBSERVED_AT) AS first_reading,
       MAX(OBSERVED_AT) AS last_reading
FROM RAW.WAIT_TIME_READING;

SELECT OFFICE_NAME, SERVICE_TYPE, WAIT_MINUTES, CONGESTION_STATUS, OBSERVED_AT
FROM CORE.CURRENT_WAIT
ORDER BY WAIT_MINUTES DESC
LIMIT 10;
