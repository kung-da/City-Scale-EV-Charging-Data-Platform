-- DQ checks are explicit and auditable. Run after staging/core builds.
DECLARE run_id STRING DEFAULT FORMAT_TIMESTAMP('%Y%m%dT%H%M%SZ', CURRENT_TIMESTAMP());
DECLARE run_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

CREATE TEMP TABLE checks AS
SELECT 'core_fact_station_fk' AS check_name, 'referential_integrity' AS check_type,
  COUNT(*) AS records_checked, COUNTIF(s.station_id IS NULL) AS records_failed,
  0.0 AS threshold
FROM ev_charging_core.fact_charging_transaction f
LEFT JOIN ev_charging_core.dim_station s USING (station_id)
UNION ALL
SELECT 'core_non_negative_measures', 'validity', COUNT(*),
  COUNTIF(duration_min < 0 OR total_elec_kwh < 0 OR total_fee < 0), 0.0
FROM ev_charging_core.fact_charging_transaction
UNION ALL
SELECT 'staging_duplicate_audit', 'uniqueness', COUNT(*),
  COUNTIF(is_exact_duplicate), 0.01
FROM ev_charging_staging.stg_orders;

INSERT INTO ev_charging_monitoring.dq_results
SELECT
  GENERATE_UUID(), run_id, check_name, 'ev_charging_core.fact_charging_transaction',
  check_type, records_checked, records_failed,
  SAFE_DIVIDE(records_failed, records_checked),
  TO_JSON_STRING(STRUCT(records_failed AS failed_rows)),
  threshold, run_ts
FROM checks;

INSERT INTO ev_charging_monitoring.dq_summary
SELECT
  run_id, COUNT(*), COUNTIF(records_failed = 0), COUNTIF(records_failed > 0),
  SAFE_DIVIDE(COUNTIF(records_failed = 0), COUNT(*)),
  CASE WHEN COUNTIF(records_failed > 0) = 0 THEN 'PASSED' ELSE 'WARNING' END,
  run_ts, NULL
FROM checks;
