-- ==============================================================================
-- EV Charging Intelligence Platform - Monitoring Layer Table Definitions
-- Description: Creates tables for data quality tracking and pipeline
--              execution audit logging
-- Idempotent: Yes (CREATE OR REPLACE TABLE)
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- dq_results: Individual data quality check results
-- Grain: One row per check execution
-- Purpose: Detailed DQ check outcomes for investigation and trending
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE ev_charging_monitoring.dq_results (
  -- Check identity
  check_id                  STRING    NOT NULL OPTIONS (description = 'Unique check execution ID (UUID or composite key)'),
  run_id                    STRING    NOT NULL OPTIONS (description = 'Pipeline run ID grouping related checks'),
  check_name                STRING    NOT NULL OPTIONS (description = 'Human-readable check name (e.g., "null_station_id_check")'),
  table_name                STRING    NOT NULL OPTIONS (description = 'Fully qualified table being checked'),
  check_type                STRING    NOT NULL OPTIONS (description = 'Check category: completeness, uniqueness, validity, consistency, reconciliation'),

  -- Results
  records_checked           INT64     OPTIONS (description = 'Total records evaluated by this check'),
  records_failed            INT64     OPTIONS (description = 'Number of records that failed the check'),
  failure_rate              FLOAT64   OPTIONS (description = 'Failure rate as decimal (records_failed / records_checked)'),
  check_passed              BOOL      NOT NULL OPTIONS (description = 'TRUE if failure_rate is within acceptable threshold'),

  -- Details
  details                   STRING    OPTIONS (description = 'JSON or text with additional check details, sample failures, or thresholds'),
  threshold                 FLOAT64   OPTIONS (description = 'Acceptable failure rate threshold (e.g., 0.01 = 1%)'),

  -- Timing
  check_timestamp           TIMESTAMP NOT NULL OPTIONS (description = 'When the check was executed')
)
OPTIONS (
  description = 'Individual data quality check results. Tracks completeness, uniqueness, validity, consistency, and reconciliation checks across all tables.'
);

-- -----------------------------------------------------------------------------
-- dq_summary: Aggregated DQ run summary
-- Grain: One row per pipeline run
-- Purpose: Quick pass/fail dashboard for pipeline health
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE ev_charging_monitoring.dq_summary (
  -- Run identity
  run_id                    STRING    NOT NULL OPTIONS (description = 'Pipeline run ID'),

  -- Aggregated results
  total_checks              INT64     NOT NULL OPTIONS (description = 'Total number of DQ checks executed in this run'),
  checks_passed             INT64     NOT NULL OPTIONS (description = 'Number of checks that passed'),
  checks_failed             INT64     NOT NULL OPTIONS (description = 'Number of checks that failed'),
  pass_rate                 FLOAT64   NOT NULL OPTIONS (description = 'Pass rate as decimal (checks_passed / total_checks)'),
  overall_status            STRING    NOT NULL OPTIONS (description = 'Overall run status: PASSED (all pass), WARNING (< 5% fail), FAILED (>= 5% fail)'),

  -- Timing
  run_timestamp             TIMESTAMP NOT NULL OPTIONS (description = 'When the DQ run was executed'),
  run_duration_seconds      FLOAT64   OPTIONS (description = 'Total duration of the DQ run in seconds')
)
OPTIONS (
  description = 'Aggregated data quality run summary. One row per pipeline run with pass/fail counts and overall health status.'
);

-- -----------------------------------------------------------------------------
-- pipeline_audit: Pipeline execution step audit log
-- Grain: One row per pipeline step execution
-- Purpose: End-to-end pipeline observability and debugging
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE ev_charging_monitoring.pipeline_audit (
  -- Step identity
  audit_id                  STRING    NOT NULL OPTIONS (description = 'Unique audit record ID'),
  run_id                    STRING    NOT NULL OPTIONS (description = 'Pipeline run ID for grouping related steps'),
  step_name                 STRING    NOT NULL OPTIONS (description = 'Pipeline step name (e.g., "load_raw_stations", "build_stg_orders", "build_fact_charging")'),
  step_order                INT64     OPTIONS (description = 'Execution order within the pipeline run'),

  -- Execution details
  status                    STRING    NOT NULL OPTIONS (description = 'Step status: STARTED, RUNNING, COMPLETED, FAILED, SKIPPED'),
  rows_processed            INT64     OPTIONS (description = 'Number of rows processed/inserted by this step'),
  rows_rejected             INT64     OPTIONS (description = 'Number of rows rejected by this step'),

  -- Timing
  start_time                TIMESTAMP NOT NULL OPTIONS (description = 'Step start timestamp'),
  end_time                  TIMESTAMP OPTIONS (description = 'Step end timestamp (NULL if still running or failed)'),
  duration_seconds          FLOAT64   OPTIONS (description = 'Step duration in seconds'),

  -- Error handling
  error_message             STRING    OPTIONS (description = 'Error message if step failed'),
  error_details             STRING    OPTIONS (description = 'Full error stack trace or additional context')
)
OPTIONS (
  description = 'Pipeline execution audit log. Tracks each step from raw ingestion through mart building with timing, row counts, and error details for debugging.'
);
