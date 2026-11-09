-- Dashboard-ready marts. All measures use CORE facts, not RAW.
DECLARE run_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

CREATE OR REPLACE TABLE ev_charging_mart.mart_executive_kpi AS
SELECT
  source_month,
  FORMAT_DATE('%B %Y', MIN(transaction_date)) AS month_name,
  COUNT(*) AS total_transactions,
  SUM(total_elec_kwh) AS total_energy_kwh,
  SUM(total_fee) AS total_revenue_cny,
  AVG(duration_min) AS avg_duration_min,
  AVG(total_elec_kwh) AS avg_energy_per_session_kwh,
  AVG(total_fee) AS avg_fee_per_session_cny,
  SAFE_DIVIDE(SUM(total_fee), SUM(total_elec_kwh)) AS avg_fee_per_kwh_cny,
  COUNT(DISTINCT station_id) AS active_stations,
  COUNT(DISTINCT pile_id) AS active_piles,
  SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT station_id)) AS avg_transactions_per_station,
  SAFE_DIVIDE(COUNTIF(equipment_classification = '直流设备'), COUNT(*)) AS dc_transaction_pct,
  SAFE_DIVIDE(SUM(IF(equipment_classification = '直流设备', total_elec_kwh, 0)), SUM(total_elec_kwh)) AS dc_energy_pct,
  run_ts AS _computed_at
FROM ev_charging_core.fact_charging_transaction
GROUP BY source_month;

CREATE OR REPLACE TABLE ev_charging_mart.mart_hourly_demand AS
SELECT
  f.source_month, EXTRACT(HOUR FROM f.charge_start_time) AS hour_of_day,
  t.time_period, t.tou_category, COUNT(*) AS transaction_count,
  AVG(f.total_elec_kwh) AS avg_energy_kwh, SUM(f.total_elec_kwh) AS total_energy_kwh,
  AVG(f.duration_min) AS avg_duration_min, AVG(f.total_fee) AS avg_fee_cny,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER (PARTITION BY f.source_month)) AS pct_of_month_transactions,
  run_ts AS _computed_at
FROM ev_charging_core.fact_charging_transaction AS f
JOIN ev_charging_core.dim_time AS t
  ON t.hour = EXTRACT(HOUR FROM f.charge_start_time)
 AND t.minute = 0
GROUP BY f.source_month, hour_of_day, t.time_period, t.tou_category;

CREATE OR REPLACE TABLE ev_charging_mart.mart_cost_analysis AS
SELECT
  s.construction_site_en,
  f.equipment_classification,
  f.source_month,
  COUNT(*) AS transaction_count,
  SUM(f.total_elec_kwh) AS total_energy_kwh,
  SUM(f.total_elec_fee) AS total_elec_fee_cny,
  SUM(f.total_service_fee) AS total_service_fee_cny,
  SUM(f.total_fee) AS total_fee_cny,
  AVG(f.total_elec_fee) AS avg_elec_fee_per_session,
  AVG(f.total_service_fee) AS avg_service_fee_per_session,
  AVG(f.total_fee) AS avg_total_fee_per_session,
  SAFE_DIVIDE(SUM(f.total_elec_fee), SUM(f.total_elec_kwh)) AS avg_elec_fee_per_kwh,
  SAFE_DIVIDE(SUM(f.total_service_fee), SUM(f.total_elec_kwh)) AS avg_service_fee_per_kwh,
  SAFE_DIVIDE(SUM(f.total_fee), SUM(f.total_elec_kwh)) AS avg_total_fee_per_kwh,
  SAFE_DIVIDE(SUM(f.total_service_fee), SUM(f.total_fee)) AS service_fee_pct,
  run_ts AS _computed_at
FROM ev_charging_core.fact_charging_transaction AS f
JOIN ev_charging_core.dim_station AS s USING (station_id)
GROUP BY s.construction_site_en, f.equipment_classification, f.source_month;

CREATE OR REPLACE TABLE ev_charging_mart.mart_station_utilization AS
SELECT
  f.station_id, f.source_month, s.construction_site_en, s.grid_x, s.grid_y,
  s.station_total_power_kw, s.charging_gun_num, COUNT(*) AS total_transactions,
  SUM(f.total_elec_kwh) AS total_energy_kwh, SUM(f.total_fee) AS total_revenue_cny,
  AVG(f.duration_min) AS avg_duration_min, AVG(f.total_elec_kwh) AS avg_energy_per_session_kwh,
  COUNTIF(f.equipment_classification = '直流设备') AS dc_transactions,
  COUNTIF(f.equipment_classification = '交流设备') AS ac_transactions,
  SUM(IF(f.equipment_classification = '直流设备', f.total_elec_kwh, 0)) AS dc_energy_kwh,
  SUM(IF(f.equipment_classification = '交流设备', f.total_elec_kwh, 0)) AS ac_energy_kwh,
  COUNT(DISTINCT f.transaction_date) AS active_days,
  SAFE_DIVIDE(COUNT(*), NULLIF(s.charging_gun_num, 0) * COUNT(DISTINCT f.transaction_date)) AS transactions_per_gun_per_day,
  SAFE_DIVIDE(SUM(f.total_elec_kwh), NULLIF(s.charging_gun_num, 0) * COUNT(DISTINCT f.transaction_date)) AS energy_per_gun_per_day_kwh,
  run_ts AS _computed_at
FROM ev_charging_core.fact_charging_transaction AS f
JOIN ev_charging_core.dim_station AS s USING (station_id)
GROUP BY f.station_id, f.source_month, s.construction_site_en, s.grid_x, s.grid_y,
  s.station_total_power_kw, s.charging_gun_num;

CREATE OR REPLACE TABLE ev_charging_mart.mart_spatial_grid_summary AS
WITH station_grid AS (
  SELECT grid_x, grid_y, COUNT(*) AS station_count,
    SUM(station_total_power_kw) AS total_installed_power_kw,
    SUM(charging_gun_num) AS total_charging_guns
  FROM ev_charging_core.dim_station
  GROUP BY grid_x, grid_y
),
dominant_site AS (
  SELECT grid_x, grid_y, construction_site_en AS dominant_site_type
  FROM (
    SELECT
      grid_x,
      grid_y,
      construction_site_en,
      COUNT(*) AS site_count,
      ROW_NUMBER() OVER (
        PARTITION BY grid_x, grid_y
        ORDER BY COUNT(*) DESC, construction_site_en
      ) AS site_rank
    FROM ev_charging_core.dim_station
    WHERE construction_site_en IS NOT NULL
    GROUP BY grid_x, grid_y, construction_site_en
  )
  WHERE site_rank = 1
),
demand AS (
  SELECT s.grid_x, s.grid_y, f.source_month,
    COUNT(*) AS transaction_count, SUM(f.total_elec_kwh) AS total_energy_kwh,
    SUM(f.total_fee) AS total_revenue_cny,
    AVG(f.total_elec_kwh) AS avg_energy_per_session_kwh,
    AVG(f.duration_min) AS avg_duration_min,
    COUNT(DISTINCT s.station_id) AS active_station_count
  FROM ev_charging_core.fact_charging_transaction AS f
  JOIN ev_charging_core.dim_station AS s USING (station_id)
  GROUP BY s.grid_x, s.grid_y, f.source_month
)
SELECT
  d.grid_x, d.grid_y, d.source_month, g.station_count,
  g.total_installed_power_kw, g.total_charging_guns,
  d.transaction_count AS total_transactions, d.total_energy_kwh, d.total_revenue_cny,
  d.avg_energy_per_session_kwh, d.avg_duration_min,
  SAFE_DIVIDE(d.transaction_count, d.active_station_count) AS transactions_per_station,
  ds.dominant_site_type,
  run_ts AS _computed_at
FROM demand AS d
JOIN station_grid AS g USING (grid_x, grid_y)
LEFT JOIN dominant_site AS ds USING (grid_x, grid_y);
