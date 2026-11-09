-- Publish validated temporary loads into the contract-defined RAW tables.
-- The source-specific tables are replaced atomically, so rerunning this script
-- does not append duplicate rows. Temporary _load_* tables must already exist.

CREATE OR REPLACE TABLE ev_charging_raw.raw_stations AS
SELECT
  geocoding,
  station_id,
  construction_site,
  station_total_power_kw,
  piles_num,
  dc_piles_num,
  ac_piles_num,
  charging_gun_num,
  dc_charging_gun_num,
  ac_charging_gun_num,
  CURRENT_TIMESTAMP() AS _ingested_at,
  'stations_public.parquet' AS _source_file
FROM ev_charging_raw._load_stations;

CREATE OR REPLACE TABLE ev_charging_raw.raw_orders_2025_01
PARTITION BY transaction_date AS
SELECT
  transaction_date,
  equipment_classification,
  rated_gun_power_kw,
  station_id,
  pile_id,
  duration_min,
  charge_start_time,
  charge_end_time,
  total_elec_kwh,
  total_elec_fee,
  total_service_fee,
  total_fee,
  CURRENT_TIMESTAMP() AS _ingested_at,
  'orders_2025-01_public.parquet' AS _source_file,
  '2025-01' AS _source_month
FROM ev_charging_raw._load_orders_2025_01;

CREATE OR REPLACE TABLE ev_charging_raw.raw_orders_2025_07
PARTITION BY transaction_date AS
SELECT
  transaction_date,
  equipment_classification,
  rated_gun_power_kw,
  station_id,
  pile_id,
  duration_min,
  charge_start_time,
  charge_end_time,
  total_elec_kwh,
  total_elec_fee,
  total_service_fee,
  total_fee,
  CURRENT_TIMESTAMP() AS _ingested_at,
  'orders_2025-07_public.parquet' AS _source_file,
  '2025-07' AS _source_month
FROM ev_charging_raw._load_orders_2025_07;
