-- ==============================================================================
-- EV Charging Intelligence Platform - Staging Layer Table Definitions
-- Description: Creates staging tables with cleaned, standardized, and validated
--              data ready for dimensional modeling
-- Idempotent: Yes (CREATE OR REPLACE TABLE)
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- stg_stations: Cleaned station master data
-- Transformations: Chinese-to-English site type mapping, geocoding parsing,
--                  residential synonym consolidation, validation
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE ev_charging_staging.stg_stations (
  -- Station identity
  station_id                  STRING    NOT NULL OPTIONS (description = 'Unique station identifier (primary key)'),
  geocoding                   STRING    OPTIONS (description = 'Original grid location code from source'),
  grid_x                      INT64     OPTIONS (description = 'Parsed anonymized grid component; not longitude'),
  grid_y                      INT64     OPTIONS (description = 'Parsed anonymized grid component; not latitude'),

  -- Site classification
  construction_site           STRING    OPTIONS (description = 'Original Chinese site type (with 居民区 consolidated to 居住区)'),
  construction_site_en        STRING    OPTIONS (description = 'English translation of construction_site'),
  is_residential_consolidated BOOL      OPTIONS (description = 'TRUE if original value was 居民区 (consolidated to 居住区/Residential areas)'),

  -- Infrastructure metrics
  station_total_power_kw      FLOAT64   OPTIONS (description = 'Total installed power capacity in kW'),
  piles_num                   INT64     OPTIONS (description = 'Total number of charging piles (cast from FLOAT64)'),
  dc_piles_num                INT64     OPTIONS (description = 'Number of DC (fast) charging piles'),
  ac_piles_num                INT64     OPTIONS (description = 'Number of AC (slow) charging piles'),
  charging_gun_num            INT64     OPTIONS (description = 'Total number of charging guns/connectors'),
  dc_charging_gun_num         INT64     OPTIONS (description = 'Number of DC charging guns'),
  ac_charging_gun_num         INT64     OPTIONS (description = 'Number of AC charging guns'),
  pile_count_components_match BOOL      NOT NULL OPTIONS (description = 'TRUE when AC+DC pile counts equal total pile count'),
  gun_count_components_match  BOOL      NOT NULL OPTIONS (description = 'TRUE when AC+DC gun counts equal total gun count'),

  -- Validation
  is_valid                    BOOL      NOT NULL OPTIONS (description = 'TRUE if record passes all validation checks'),
  validation_notes            STRING    OPTIONS (description = 'Semicolon-delimited list of validation issues found'),

  -- Audit
  _ingested_at                TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp of staging load'),
  _source_file                STRING    NOT NULL OPTIONS (description = 'Original source file name')
)
OPTIONS (
  description = 'Staged and validated station master data. Chinese site types translated to English, geocoding parsed to grid coordinates, residential synonyms consolidated.'
);

-- -----------------------------------------------------------------------------
-- stg_orders: Cleaned and deduplicated charging orders (Jan + Jul combined)
-- Transformations: UNION ALL both months, dedup, type casting, nullable preservation,
--                  validation flags, zero-consumption flagging
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE ev_charging_staging.stg_orders (
  -- Transaction identity
  transaction_date            DATE      NOT NULL OPTIONS (description = 'Native source transaction date'),
  source_month                STRING    NOT NULL OPTIONS (description = 'Source month: "2025-01" or "2025-07"'),
  source_row_hash             STRING    NOT NULL OPTIONS (description = 'Deterministic hash of the source row; technical lineage key, not a source transaction ID'),

  -- Equipment details
  equipment_classification    STRING    OPTIONS (description = 'Equipment type: 直流设备 (DC) or 交流设备 (AC); nullable in January source data'),
  rated_gun_power_kw          FLOAT64   OPTIONS (description = 'Rated power of the charging gun in kW'),

  -- Station/pile reference
  station_id                  STRING    NOT NULL OPTIONS (description = 'Foreign key to station master data'),
  pile_id                     STRING    OPTIONS (description = 'Individual charging pile identifier'),

  -- Session timing
  duration_min                FLOAT64   OPTIONS (description = 'Total session duration in minutes'),
  charge_start_time           TIMESTAMP OPTIONS (description = 'Charging session start timestamp'),
  charge_end_time             TIMESTAMP OPTIONS (description = 'Charging session end timestamp'),

  -- Consumption and fees
  total_elec_kwh              FLOAT64   OPTIONS (description = 'Total electricity consumed in kWh'),
  total_elec_fee              FLOAT64   OPTIONS (description = 'Electricity cost in CNY'),
  total_service_fee           FLOAT64   OPTIONS (description = 'Service fee in CNY'),
  total_fee                   FLOAT64   OPTIONS (description = 'Total fee (elec + service) in CNY'),

  -- Quality flags
  is_valid                    BOOL      NOT NULL OPTIONS (description = 'TRUE if record passes all validation checks and is non-zero consumption'),
  is_zero_consumption         BOOL      NOT NULL OPTIONS (description = 'TRUE if total_elec_kwh = 0 or IS NULL'),
  is_imputed_classification   BOOL      NOT NULL OPTIONS (description = 'TRUE only if a documented lookup supports imputation; FALSE for current source'),
  is_exact_duplicate          BOOL      NOT NULL OPTIONS (description = 'TRUE for an exact duplicate occurrence after the canonical source row'),
  validation_notes            STRING    OPTIONS (description = 'Semicolon-delimited list of validation issues found'),

  -- Audit
  _ingested_at                TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp of staging load'),
  _source_file                STRING    NOT NULL OPTIONS (description = 'Original source file name')
)
PARTITION BY transaction_date
CLUSTER BY station_id
OPTIONS (
  description = 'Staged and validated charging orders combining Jan and Jul 2025. All source rows are retained, exact duplicates are flagged, nullable values are preserved, and CORE excludes non-canonical or invalid rows. Partitioned by transaction_date, clustered by station_id.'
);

-- -----------------------------------------------------------------------------
-- stg_rejected_records: Records that failed validation checks
-- Used for DQ monitoring and root cause analysis
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE ev_charging_staging.stg_rejected_records (
  -- Record identity
  transaction_date            DATE      OPTIONS (description = 'Transaction date of the rejected record'),
  source_month                STRING    OPTIONS (description = 'Source month: "2025-01" or "2025-07"'),
  station_id                  STRING    OPTIONS (description = 'Station ID of the rejected record'),
  pile_id                     STRING    OPTIONS (description = 'Pile ID of the rejected record'),
  charge_start_time           TIMESTAMP OPTIONS (description = 'Session start time of the rejected record'),
  charge_end_time             TIMESTAMP OPTIONS (description = 'Session end time of the rejected record'),
  source_row_hash             STRING    OPTIONS (description = 'Technical lineage hash of the rejected source row'),

  -- Original values for debugging
  equipment_classification    STRING    OPTIONS (description = 'Original equipment classification value'),
  rated_gun_power_kw          FLOAT64   OPTIONS (description = 'Original rated gun power'),
  duration_min                FLOAT64   OPTIONS (description = 'Original duration in minutes'),
  total_elec_kwh              FLOAT64   OPTIONS (description = 'Original energy consumed'),
  total_elec_fee              FLOAT64   OPTIONS (description = 'Original electricity fee'),
  total_service_fee           FLOAT64   OPTIONS (description = 'Original service fee'),
  total_fee                   FLOAT64   OPTIONS (description = 'Original total fee'),

  -- Rejection metadata
  rejection_reason            STRING    NOT NULL OPTIONS (description = 'Reason for rejection (e.g., "negative_duration", "end_before_start", "zero_consumption")'),
  is_zero_consumption         BOOL      OPTIONS (description = 'TRUE if rejected due to zero energy consumption'),

  -- Audit
  _rejected_at                TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when record was identified as rejected'),
  _source_file                STRING    OPTIONS (description = 'Original source file name')
)
PARTITION BY transaction_date
OPTIONS (
  description = 'Rejected charging order records that failed validation. Used for data quality monitoring, root cause analysis, and reconciliation.'
);
