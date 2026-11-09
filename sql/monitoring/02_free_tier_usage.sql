-- Cost guardrail report. Run in the same location as the datasets.
-- These values are monitoring estimates, not a billing statement.
DECLARE free_storage_gib NUMERIC DEFAULT 10;
DECLARE free_query_tib NUMERIC DEFAULT 1;

SELECT
  'bigquery_storage' AS metric,
  ROUND(SUM(total_logical_bytes) / POW(1024, 3), 3) AS used_gib,
  free_storage_gib AS free_tier_limit,
  ROUND(SUM(total_logical_bytes) / POW(1024, 3) / free_storage_gib * 100, 2) AS used_percent,
  IF(SUM(total_logical_bytes) <= free_storage_gib * POW(1024, 3), 'WITHIN_LIMIT', 'REVIEW') AS status
FROM `region-us-central1`.INFORMATION_SCHEMA.TABLE_STORAGE_BY_PROJECT
WHERE table_schema IN (
  'ev_charging_raw',
  'ev_charging_staging',
  'ev_charging_core',
  'ev_charging_mart',
  'ev_charging_monitoring'
)

UNION ALL

SELECT
  'bigquery_query_current_month',
  ROUND(SUM(total_bytes_processed) / POW(1024, 4), 3),
  free_query_tib,
  ROUND(SUM(total_bytes_processed) / POW(1024, 4) / free_query_tib * 100, 2),
  IF(SUM(total_bytes_processed) <= free_query_tib * POW(1024, 4), 'WITHIN_LIMIT', 'REVIEW')
FROM `region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), MONTH)
  AND state = 'DONE'
  AND error_result IS NULL
  AND job_type = 'QUERY';

SELECT
  DATE(creation_time) AS usage_date,
  COUNT(*) AS query_jobs,
  ROUND(SUM(total_bytes_processed) / POW(1024, 3), 3) AS processed_gib
FROM `region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time >= TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), MONTH)
  AND state = 'DONE'
  AND error_result IS NULL
  AND job_type = 'QUERY'
GROUP BY usage_date
ORDER BY usage_date DESC;
