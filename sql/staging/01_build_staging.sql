-- Build staging tables from RAW. RAW is never modified.
DECLARE run_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

CREATE OR REPLACE TABLE ev_charging_staging.stg_stations AS
WITH source AS (
  SELECT
    geocoding, station_id, construction_site, station_total_power_kw,
    piles_num, dc_piles_num, ac_piles_num, charging_gun_num,
    dc_charging_gun_num, ac_charging_gun_num,
    SAFE_CAST(SPLIT(geocoding, '_')[SAFE_OFFSET(0)] AS INT64) AS grid_x,
    SAFE_CAST(SPLIT(geocoding, '_')[SAFE_OFFSET(1)] AS INT64) AS grid_y
  FROM ev_charging_raw.raw_stations
),
mapped AS (
  SELECT
    *,
    CASE construction_site
      WHEN '大型建筑配建停车场' THEN 'Parking facilities for large buildings'
      WHEN '居住区' THEN 'Residential areas'
      WHEN '居民区' THEN 'Residential areas'
      WHEN '写字楼' THEN 'Office buildings'
      WHEN '工业园区' THEN 'Industrial parks'
      WHEN '公共机构' THEN 'Public institutions'
      WHEN '大型文体设施' THEN 'Large cultural and sports venues'
      WHEN '交通枢纽' THEN 'Transportation hubs'
      WHEN '其他' THEN 'Other'
      WHEN '城市绿地' THEN 'Urban green spaces'
      WHEN '加油加气站' THEN 'Fuel and gas stations'
      WHEN '风景区' THEN 'Scenic areas'
      WHEN '路边停车位' THEN 'On-street parking'
      WHEN '企事业单位' THEN 'Enterprises and institutions'
      WHEN '公交场站' THEN 'Bus stations'
      WHEN '城际高速服务区' THEN 'Intercity highway service areas'
      WHEN '出租车' THEN 'Taxi dedicated station'
      ELSE 'Unmapped'
    END AS construction_site_en,
    construction_site = '居民区' AS is_residential_consolidated,
    dc_piles_num + ac_piles_num = piles_num AS pile_count_components_match,
    dc_charging_gun_num + ac_charging_gun_num = charging_gun_num AS gun_count_components_match
  FROM source
)
SELECT
  station_id, geocoding, grid_x, grid_y, construction_site,
  construction_site_en, is_residential_consolidated,
  CAST(station_total_power_kw AS FLOAT64) AS station_total_power_kw,
  CAST(piles_num AS INT64) AS piles_num,
  CAST(dc_piles_num AS INT64) AS dc_piles_num,
  CAST(ac_piles_num AS INT64) AS ac_piles_num,
  CAST(charging_gun_num AS INT64) AS charging_gun_num,
  CAST(dc_charging_gun_num AS INT64) AS dc_charging_gun_num,
  CAST(ac_charging_gun_num AS INT64) AS ac_charging_gun_num,
  pile_count_components_match, gun_count_components_match,
  station_id IS NOT NULL AND station_total_power_kw >= 0
    AND piles_num >= 0 AND dc_piles_num >= 0 AND ac_piles_num >= 0 AS is_valid,
  CASE
    WHEN NOT pile_count_components_match THEN 'pile_component_mismatch;'
    ELSE ''
  END ||
  CASE
    WHEN NOT gun_count_components_match THEN 'gun_component_mismatch;'
    ELSE ''
  END AS validation_notes,
  run_ts AS _ingested_at,
  'stations_public.parquet' AS _source_file
FROM mapped;

CREATE OR REPLACE TABLE ev_charging_staging.stg_orders
PARTITION BY transaction_date
CLUSTER BY station_id AS
WITH source AS (
  SELECT
    transaction_date, equipment_classification, rated_gun_power_kw, station_id,
    pile_id, duration_min, charge_start_time, charge_end_time, total_elec_kwh,
    total_elec_fee, total_service_fee, total_fee,
    '2025-01' AS source_month, 'orders_2025-01_public.parquet' AS _source_file
  FROM ev_charging_raw.raw_orders_2025_01
  UNION ALL
  SELECT
    transaction_date, equipment_classification, rated_gun_power_kw, station_id,
    pile_id, duration_min, charge_start_time, charge_end_time, total_elec_kwh,
    total_elec_fee, total_service_fee, total_fee,
    '2025-07' AS source_month, 'orders_2025-07_public.parquet' AS _source_file
  FROM ev_charging_raw.raw_orders_2025_07
),
hashed AS (
  SELECT
    *,
    TO_HEX(SHA256(TO_JSON_STRING(STRUCT(
      transaction_date, equipment_classification, rated_gun_power_kw,
      station_id, pile_id, duration_min, charge_start_time, charge_end_time,
      total_elec_kwh, total_elec_fee, total_service_fee, total_fee
    )))) AS source_row_hash
  FROM source
),
ranked AS (
  SELECT
    transaction_date, equipment_classification, rated_gun_power_kw, station_id,
    pile_id, duration_min, charge_start_time, charge_end_time, total_elec_kwh,
    total_elec_fee, total_service_fee, total_fee, source_month, _source_file,
    source_row_hash,
    ROW_NUMBER() OVER (PARTITION BY source_month, source_row_hash ORDER BY _source_file) AS duplicate_rank
  FROM hashed
)
SELECT
  transaction_date, source_month, source_row_hash, equipment_classification,
  rated_gun_power_kw, station_id, pile_id, duration_min, charge_start_time,
  charge_end_time, total_elec_kwh, total_elec_fee, total_service_fee, total_fee,
  duplicate_rank = 1
    AND station_id IS NOT NULL
    AND charge_start_time IS NOT NULL
    AND charge_end_time IS NOT NULL
    AND charge_end_time >= charge_start_time
    AND COALESCE(duration_min, 0) >= 0
    AND COALESCE(total_elec_kwh, 0) >= 0
    AND COALESCE(total_elec_fee, 0) >= 0
    AND COALESCE(total_service_fee, 0) >= 0
    AND COALESCE(total_fee, 0) >= 0 AS is_valid,
  total_elec_kwh IS NULL OR total_elec_kwh = 0 AS is_zero_consumption,
  FALSE AS is_imputed_classification,
  duplicate_rank > 1 AS is_exact_duplicate,
  CASE
    WHEN duplicate_rank > 1 THEN 'exact_duplicate'
    WHEN station_id IS NULL THEN 'missing_station_id'
    WHEN charge_end_time < charge_start_time THEN 'end_before_start'
    WHEN duration_min < 0 OR total_elec_kwh < 0 OR total_elec_fee < 0
      OR total_service_fee < 0 OR total_fee < 0 THEN 'negative_measure'
    ELSE NULL
  END AS validation_notes,
  run_ts AS _ingested_at, _source_file
FROM ranked;
