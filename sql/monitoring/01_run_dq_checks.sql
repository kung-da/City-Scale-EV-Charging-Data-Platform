-- Data quality checks are threshold-aware and append one auditable result per run.
DECLARE run_id STRING DEFAULT GENERATE_UUID();
DECLARE run_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

CREATE TEMP TABLE checks AS
SELECT
  'core_fact_station_fk' AS check_name,
  'ev_charging_core.fact_charging_transaction' AS table_name,
  'referential_integrity' AS check_type,
  COUNT(*) AS records_checked,
  COUNTIF(s.station_id IS NULL) AS records_failed,
  0.0 AS threshold
FROM ev_charging_core.fact_charging_transaction AS f
LEFT JOIN ev_charging_core.dim_station AS s USING (station_id)

UNION ALL

SELECT
  'core_non_negative_measures',
  'ev_charging_core.fact_charging_transaction',
  'validity',
  COUNT(*),
  COUNTIF(duration_min < 0 OR total_elec_kwh < 0 OR total_fee < 0),
  0.0
FROM ev_charging_core.fact_charging_transaction

UNION ALL

SELECT
  'staging_duplicate_audit',
  'ev_charging_staging.stg_orders',
  'uniqueness',
  COUNT(*),
  COUNTIF(is_exact_duplicate),
  0.01
FROM ev_charging_staging.stg_orders

UNION ALL

SELECT
  'staging_station_reconciliation',
  'ev_charging_staging.stg_orders',
  'referential_integrity',
  COUNT(*),
  COUNTIF(s.station_id IS NULL),
  0.0
FROM ev_charging_staging.stg_orders AS o
LEFT JOIN ev_charging_staging.stg_stations AS s USING (station_id)

UNION ALL

SELECT
  'core_source_reconciliation',
  'ev_charging_core.fact_charging_transaction',
  'reconciliation',
  COUNT(*),
  COUNTIF(source_row_hash IS NULL OR source_month IS NULL),
  0.0
FROM ev_charging_core.fact_charging_transaction;

INSERT INTO ev_charging_monitoring.dq_results (
  check_id, run_id, check_name, table_name, check_type,
  records_checked, records_failed, failure_rate, check_passed,
  details, threshold, check_timestamp
)
SELECT
  GENERATE_UUID(),
  run_id,
  check_name,
  table_name,
  check_type,
  records_checked,
  records_failed,
  SAFE_DIVIDE(records_failed, records_checked),
  SAFE_DIVIDE(records_failed, records_checked) <= threshold,
  TO_JSON_STRING(STRUCT(records_failed AS failed_rows, records_checked AS checked_rows)),
  threshold,
  run_ts
FROM checks;

INSERT INTO ev_charging_monitoring.dq_summary (
  run_id, total_checks, checks_passed, checks_failed, pass_rate,
  overall_status, run_timestamp, run_duration_seconds
)
SELECT
  run_id,
  COUNT(*),
  COUNTIF(SAFE_DIVIDE(records_failed, records_checked) <= threshold),
  COUNTIF(SAFE_DIVIDE(records_failed, records_checked) > threshold),
  SAFE_DIVIDE(COUNTIF(SAFE_DIVIDE(records_failed, records_checked) <= threshold), COUNT(*)),
  CASE
    WHEN COUNTIF(SAFE_DIVIDE(records_failed, records_checked) > threshold) = 0 THEN 'PASSED'
    ELSE 'FAILED'
  END,
  run_ts,
  NULL
FROM checks;
