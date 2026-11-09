-- ==============================================================================
-- EV Charging Intelligence Platform - Raw Layer Table Definitions
-- Description: Creates raw tables matching source parquet schemas exactly,
--              plus audit columns for lineage tracking
-- Idempotent: Yes (CREATE TABLE IF NOT EXISTS). Loading is a separate step.
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- raw_stations: Exact copy of stations_public.parquet (8,553 rows)
-- Source columns: geocoding, station_id (PK), construction_site (17 Chinese
--                 categories), power/pile/gun counts
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_raw.raw_stations (
  -- Source columns (match parquet schema exactly)
  geocoding                 STRING    OPTIONS (description = 'Anonymized grid code from source (for example, "9891_4446"; not longitude/latitude)'),
  station_id                STRING    NOT NULL OPTIONS (description = 'Unique station identifier (primary key in source)'),
  construction_site         STRING    OPTIONS (description = 'Station site type in Chinese (17 categories, includes synonyms 居住区/居民区)'),
  station_total_power_kw    FLOAT64   OPTIONS (description = 'Total installed power capacity in kilowatts'),
  piles_num                 FLOAT64   OPTIONS (description = 'Total number of charging piles'),
  dc_piles_num              FLOAT64   OPTIONS (description = 'Number of DC (fast) charging piles'),
  ac_piles_num              FLOAT64   OPTIONS (description = 'Number of AC (slow) charging piles'),
  charging_gun_num          FLOAT64   OPTIONS (description = 'Total number of charging guns/connectors'),
  dc_charging_gun_num       FLOAT64   OPTIONS (description = 'Number of DC charging guns'),
  ac_charging_gun_num       FLOAT64   OPTIONS (description = 'Number of AC charging guns'),

  -- Audit columns for data lineage
  _ingested_at              TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when record was loaded into BigQuery'),
  _source_file              STRING    NOT NULL OPTIONS (description = 'Source file name (e.g., "stations_public.parquet")')
)
OPTIONS (
  description = 'Raw landing table for station master data from stations_public.parquet. 8,553 stations with location, site type, and infrastructure counts.'
);

-- -----------------------------------------------------------------------------
-- raw_orders_2025_01: Exact copy of orders_2025-01_public.parquet (2,137,234 rows)
-- Known issues: 1,179 nulls in equipment_classification/rated_gun_power_kw,
--               34,551 zero-energy records, 1 duplicate row
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_raw.raw_orders_2025_01 (
  -- Source columns (match parquet schema exactly)
  transaction_date          DATE      OPTIONS (description = 'Transaction date stored as native Parquet date32 value'),
  equipment_classification  STRING    OPTIONS (description = 'Equipment type: 直流设备 (DC) or 交流设备 (AC). 1,179 nulls in Jan.'),
  rated_gun_power_kw        FLOAT64   OPTIONS (description = 'Rated power of the charging gun in kW. 1,179 nulls in Jan.'),
  station_id                STRING    OPTIONS (description = 'Foreign key to station master data'),
  pile_id                   STRING    OPTIONS (description = 'Individual charging pile identifier'),
  duration_min              FLOAT64   OPTIONS (description = 'Total session duration in minutes (plug-in to plug-out)'),
  charge_start_time         TIMESTAMP OPTIONS (description = 'Charging session start timestamp'),
  charge_end_time           TIMESTAMP OPTIONS (description = 'Charging session end timestamp'),
  total_elec_kwh            FLOAT64   OPTIONS (description = 'Total electricity consumed in kWh'),
  total_elec_fee            FLOAT64   OPTIONS (description = 'Electricity cost in CNY'),
  total_service_fee         FLOAT64   OPTIONS (description = 'Service fee in CNY'),
  total_fee                 FLOAT64   OPTIONS (description = 'Total fee (elec + service) in CNY'),

  -- Audit columns
  _ingested_at              TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when record was loaded into BigQuery'),
  _source_file              STRING    NOT NULL OPTIONS (description = 'Source file name'),
  _source_month             STRING    NOT NULL OPTIONS (description = 'Source month identifier (e.g., "2025-01")')
)
PARTITION BY transaction_date
OPTIONS (
  description = 'Raw landing table for January 2025 charging orders. 2,137,234 rows with known data quality issues: 1,179 null classifications, 34,551 zero-energy records, 1 duplicate.'
);

-- -----------------------------------------------------------------------------
-- raw_orders_2025_07: Exact copy of orders_2025-07_public.parquet (6,407,461 rows)
-- Known issues: 3,406 full-row duplicates, 792 zero-energy records, and
-- some session timestamps outside the transaction-date month.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_raw.raw_orders_2025_07 (
  -- Source columns (match parquet schema exactly)
  transaction_date          DATE      OPTIONS (description = 'Transaction date stored as native Parquet date32 value'),
  equipment_classification  STRING    OPTIONS (description = 'Equipment type: 直流设备 (DC) or 交流设备 (AC)'),
  rated_gun_power_kw        FLOAT64   OPTIONS (description = 'Rated power of the charging gun in kW'),
  station_id                STRING    OPTIONS (description = 'Foreign key to station master data'),
  pile_id                   STRING    OPTIONS (description = 'Individual charging pile identifier'),
  duration_min              FLOAT64   OPTIONS (description = 'Total session duration in minutes (plug-in to plug-out)'),
  charge_start_time         TIMESTAMP OPTIONS (description = 'Charging session start timestamp'),
  charge_end_time           TIMESTAMP OPTIONS (description = 'Charging session end timestamp'),
  total_elec_kwh            FLOAT64   OPTIONS (description = 'Total electricity consumed in kWh'),
  total_elec_fee            FLOAT64   OPTIONS (description = 'Electricity cost in CNY'),
  total_service_fee         FLOAT64   OPTIONS (description = 'Service fee in CNY'),
  total_fee                 FLOAT64   OPTIONS (description = 'Total fee (elec + service) in CNY'),

  -- Audit columns
  _ingested_at              TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when record was loaded into BigQuery'),
  _source_file              STRING    NOT NULL OPTIONS (description = 'Source file name'),
  _source_month             STRING    NOT NULL OPTIONS (description = 'Source month identifier (e.g., "2025-07")')
)
PARTITION BY transaction_date
OPTIONS (
  description = 'Raw landing table for July 2025 charging orders. 6,407,461 rows with known data quality issues: 3,406 duplicates, 792 zero-energy records, and timestamp/date boundary cases.'
);
