-- Build the dimensional model from canonical staging rows.
DECLARE run_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

CREATE OR REPLACE TABLE ev_charging_core.dim_station AS
SELECT
  FARM_FINGERPRINT(station_id) AS station_key,
  station_id, geocoding, grid_x, grid_y, construction_site_en,
  construction_site_en = 'Residential areas' AS is_residential,
  station_total_power_kw, piles_num, dc_piles_num, ac_piles_num,
  charging_gun_num, dc_charging_gun_num, ac_charging_gun_num,
  run_ts AS _loaded_at
FROM ev_charging_staging.stg_stations
WHERE is_valid;

CREATE OR REPLACE TABLE ev_charging_core.dim_date AS
WITH dates AS (
  SELECT day AS full_date
  FROM UNNEST(GENERATE_DATE_ARRAY('2025-01-01', '2025-07-31')) AS day
)
SELECT
  CAST(FORMAT_DATE('%Y%m%d', full_date) AS INT64) AS date_key,
  full_date, EXTRACT(YEAR FROM full_date) AS year,
  EXTRACT(QUARTER FROM full_date) AS quarter,
  EXTRACT(MONTH FROM full_date) AS month,
  FORMAT_DATE('%B', full_date) AS month_name,
  EXTRACT(DAY FROM full_date) AS day,
  EXTRACT(DAYOFWEEK FROM full_date) AS day_of_week,
  FORMAT_DATE('%A', full_date) AS day_name,
  EXTRACT(DAYOFWEEK FROM full_date) IN (1, 7) AS is_weekend,
  EXTRACT(MONTH FROM full_date) = 1 AS is_january,
  EXTRACT(MONTH FROM full_date) = 7 AS is_july
FROM dates;

CREATE OR REPLACE TABLE ev_charging_core.dim_time AS
WITH minutes AS (
  SELECT minute_of_day
  FROM UNNEST(GENERATE_ARRAY(0, 1439)) AS minute_of_day
)
SELECT
  CAST(FORMAT('%02d%02d', DIV(minute_of_day, 60), MOD(minute_of_day, 60)) AS INT64) AS time_key,
  DIV(minute_of_day, 60) AS hour,
  MOD(minute_of_day, 60) AS minute,
  CASE
    WHEN DIV(minute_of_day, 60) BETWEEN 6 AND 11 THEN 'Morning'
    WHEN DIV(minute_of_day, 60) BETWEEN 12 AND 17 THEN 'Afternoon'
    WHEN DIV(minute_of_day, 60) BETWEEN 18 AND 21 THEN 'Evening'
    ELSE 'Night'
  END AS time_period,
  CASE
    WHEN DIV(minute_of_day, 60) >= 23 OR DIV(minute_of_day, 60) < 7 THEN 'Valley'
    WHEN DIV(minute_of_day, 60) BETWEEN 8 AND 10
      OR DIV(minute_of_day, 60) IN (14, 18, 19, 20) THEN 'Peak'
    ELSE 'Flat'
  END AS tou_category
FROM minutes;

CREATE OR REPLACE TABLE ev_charging_core.fact_charging_transaction
PARTITION BY transaction_date
CLUSTER BY station_id, equipment_classification AS
SELECT
  FARM_FINGERPRINT(CONCAT(source_month, ':', source_row_hash)) AS transaction_key,
  FARM_FINGERPRINT(o.station_id) AS station_key,
  CAST(FORMAT_DATE('%Y%m%d', o.transaction_date) AS INT64) AS date_key,
  CAST(FORMAT('%02d%02d', EXTRACT(HOUR FROM o.charge_start_time), EXTRACT(MINUTE FROM o.charge_start_time)) AS INT64) AS start_time_key,
  o.station_id, o.pile_id, o.equipment_classification, o.transaction_date,
  o.source_month, o.source_row_hash, o.charge_start_time, o.charge_end_time,
  o.duration_min, o.rated_gun_power_kw, o.total_elec_kwh, o.total_elec_fee,
  o.total_service_fee, o.total_fee,
  SAFE_DIVIDE(o.total_elec_kwh, o.duration_min / 60) AS avg_charging_power_kw,
  SAFE_DIVIDE(o.total_elec_kwh, o.rated_gun_power_kw * 0.9) * 60 AS estimated_active_charge_min,
  GREATEST(
    o.duration_min - SAFE_DIVIDE(o.total_elec_kwh, o.rated_gun_power_kw * 0.9) * 60,
    0
  ) AS estimated_idle_min
FROM ev_charging_staging.stg_orders AS o
JOIN ev_charging_core.dim_station AS s USING (station_id)
WHERE o.is_valid AND NOT o.is_zero_consumption;
