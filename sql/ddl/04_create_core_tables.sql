-- ==============================================================================
-- EV Charging Intelligence Platform - Core Layer Table Definitions (Star Schema)
-- Description: Creates dimensional model with dimension and fact tables
--              for analytical workloads
-- Idempotent: Yes (CREATE TABLE IF NOT EXISTS). Transformation is separate.
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- dim_station: Station dimension with surrogate key
-- Grain: One row per unique station
-- Source: ev_charging_staging.stg_stations
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_core.dim_station (
  -- Surrogate key
  station_key               INT64     NOT NULL OPTIONS (description = 'Surrogate key generated via FARM_FINGERPRINT(station_id)'),

  -- Natural key
  station_id                STRING    NOT NULL OPTIONS (description = 'Natural key / business identifier for the station'),

  -- Location attributes
  geocoding                 STRING    OPTIONS (description = 'Original anonymized grid code; not longitude/latitude'),
  grid_x                      INT64     OPTIONS (description = 'Parsed anonymized grid component; not longitude'),
  grid_y                      INT64     OPTIONS (description = 'Parsed anonymized grid component; not latitude'),

  -- Site classification
  construction_site_en      STRING    OPTIONS (description = 'English site type (e.g., "Residential areas", "Office buildings")'),
  is_residential            BOOL      OPTIONS (description = 'TRUE if site type is Residential areas (including consolidated 居民区)'),

  -- Infrastructure metrics
  station_total_power_kw    FLOAT64   OPTIONS (description = 'Total installed power capacity in kW'),
  piles_num                 INT64     OPTIONS (description = 'Total number of charging piles'),
  dc_piles_num              INT64     OPTIONS (description = 'Number of DC (fast) charging piles'),
  ac_piles_num              INT64     OPTIONS (description = 'Number of AC (slow) charging piles'),
  charging_gun_num          INT64     OPTIONS (description = 'Total number of charging guns'),
  dc_charging_gun_num       INT64     OPTIONS (description = 'Number of DC charging guns'),
  ac_charging_gun_num       INT64     OPTIONS (description = 'Number of AC charging guns'),

  -- Audit
  _loaded_at                TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when record was loaded into core layer')
)
OPTIONS (
  description = 'Station dimension table. One row per station with location, site type (English), and infrastructure metrics. Surrogate key via FARM_FINGERPRINT.'
);

-- -----------------------------------------------------------------------------
-- dim_date: Date dimension covering the full analysis period
-- Grain: One row per calendar date
-- Range: 2025-01-01 to 2025-07-31, with session timestamps checked separately
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_core.dim_date (
  -- Keys
  date_key                  INT64     NOT NULL OPTIONS (description = 'Date surrogate key in YYYYMMDD format (e.g., 20250101)'),
  full_date                 DATE      NOT NULL OPTIONS (description = 'Calendar date'),

  -- Date hierarchy
  year                      INT64     NOT NULL OPTIONS (description = 'Calendar year (e.g., 2025)'),
  quarter                   INT64     NOT NULL OPTIONS (description = 'Calendar quarter (1-4)'),
  month                     INT64     NOT NULL OPTIONS (description = 'Calendar month (1-12)'),
  month_name                STRING    NOT NULL OPTIONS (description = 'Full month name (e.g., "January")'),
  day                       INT64     NOT NULL OPTIONS (description = 'Day of month (1-31)'),
  day_of_week               INT64     NOT NULL OPTIONS (description = 'Day of week (1=Sunday, 7=Saturday in BigQuery)'),
  day_name                  STRING    NOT NULL OPTIONS (description = 'Full day name (e.g., "Monday")'),

  -- Flags
  is_weekend                BOOL      NOT NULL OPTIONS (description = 'TRUE if Saturday or Sunday'),
  is_january                BOOL      NOT NULL OPTIONS (description = 'TRUE if month is January (winter baseline)'),
  is_july                   BOOL      NOT NULL OPTIONS (description = 'TRUE if month is July (summer peak)')
)
OPTIONS (
  description = 'Date dimension for the EV charging analysis period (2024-12-31 to 2025-08-01). Includes date hierarchy, day names, and seasonal flags for Jan/Jul comparison.'
);

-- -----------------------------------------------------------------------------
-- dim_time: Time-of-day dimension at minute granularity
-- Grain: One row per minute of the day (1,440 rows)
-- Includes time periods and Time-of-Use (TOU) pricing categories
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_core.dim_time (
  -- Key
  time_key                  INT64     NOT NULL OPTIONS (description = 'Time surrogate key in HHMM format (e.g., 0830 = 8:30 AM, 1415 = 2:15 PM)'),

  -- Time components
  hour                      INT64     NOT NULL OPTIONS (description = 'Hour of day (0-23)'),
  minute                    INT64     NOT NULL OPTIONS (description = 'Minute of hour (0-59)'),

  -- Time classification
  time_period               STRING    NOT NULL OPTIONS (description = 'Time-of-day period: Morning (06:00-11:59), Afternoon (12:00-17:59), Evening (18:00-21:59), Night (22:00-05:59)'),

  -- TOU pricing category (China summer electricity pricing tiers)
  tou_category              STRING    NOT NULL OPTIONS (description = 'Time-of-Use pricing tier for summer: Valley (23:00-06:59), Flat (07:00-07:59, 11:00-13:59, 15:00-17:59, 21:00-22:59), Peak (08:00-10:59, 14:00-14:59, 18:00-20:59), Spike (none in standard schedule)')
)
OPTIONS (
  description = 'Time dimension at minute granularity (1,440 rows). Classifies each minute into time periods (Morning/Afternoon/Evening/Night) and TOU pricing categories (Valley/Flat/Peak/Spike) for summer electricity rates.'
);

-- -----------------------------------------------------------------------------
-- fact_charging_transaction: Central fact table for all charging sessions
-- Grain: One row per valid charging transaction
-- Source: ev_charging_staging.stg_orders (is_valid = TRUE only)
-- Partitioned by transaction_date, clustered by station_id and equipment type
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_core.fact_charging_transaction (
  -- Technical key (no source transaction ID is provided)
  transaction_key             INT64     NOT NULL OPTIONS (description = 'Deterministic technical key derived from source_month and source_row_hash; not a source business ID'),

  -- Foreign keys to dimensions
  station_key                 INT64     NOT NULL OPTIONS (description = 'FK to dim_station.station_key'),
  date_key                    INT64     NOT NULL OPTIONS (description = 'FK to dim_date.date_key (based on transaction_date)'),
  start_time_key              INT64     NOT NULL OPTIONS (description = 'FK to dim_time.time_key (based on charge_start_time hour:minute)'),

  -- Degenerate dimensions (kept in fact for drill-through)
  station_id                  STRING    NOT NULL OPTIONS (description = 'Station natural key (degenerate dimension)'),
  pile_id                     STRING    OPTIONS (description = 'Pile identifier (degenerate dimension)'),
  equipment_classification    STRING    OPTIONS (description = 'Equipment type: 直流设备 (DC) or 交流设备 (AC)'),
  transaction_date            DATE      NOT NULL OPTIONS (description = 'Transaction date (partition column)'),
  source_month                STRING    NOT NULL OPTIONS (description = 'Source month identifier: "2025-01" or "2025-07"'),
  source_row_hash             STRING    NOT NULL OPTIONS (description = 'Technical lineage hash of the canonical source row'),

  -- Time measures
  charge_start_time           TIMESTAMP OPTIONS (description = 'Charging session start timestamp'),
  charge_end_time             TIMESTAMP OPTIONS (description = 'Charging session end timestamp'),
  duration_min                FLOAT64   OPTIONS (description = 'Total session duration in minutes (plug-in to plug-out)'),

  -- Energy measures
  rated_gun_power_kw          FLOAT64   OPTIONS (description = 'Rated power of the charging gun in kW'),
  total_elec_kwh              FLOAT64   OPTIONS (description = 'Total electricity consumed in kWh'),

  -- Fee measures
  total_elec_fee              FLOAT64   OPTIONS (description = 'Electricity cost in CNY'),
  total_service_fee           FLOAT64   OPTIONS (description = 'Service fee in CNY'),
  total_fee                   FLOAT64   OPTIONS (description = 'Total fee (elec + service) in CNY'),

  -- Calculated measures
  avg_charging_power_kw       FLOAT64   OPTIONS (description = 'Average charging power = total_elec_kwh / (duration_min / 60). NULL if duration_min <= 0.'),
  estimated_active_charge_min FLOAT64   OPTIONS (description = 'Estimated active charging time = (total_elec_kwh / (rated_gun_power_kw * 0.9)) * 60. Assumes 90% charging efficiency.'),
  estimated_idle_min          FLOAT64   OPTIONS (description = 'Estimated idle time = duration_min - estimated_active_charge_min, floored at 0.')
)
PARTITION BY transaction_date
CLUSTER BY station_id, equipment_classification
OPTIONS (
  description = 'Central fact table for valid EV charging transactions. Grain: one session. Contains all measures (duration, energy, fees) plus calculated power and idle time estimates. Partitioned by transaction_date, clustered by station_id and equipment_classification.'
);
