-- ==============================================================================
-- EV Charging Intelligence Platform - Dataset Creation
-- Description: Creates all BigQuery datasets for the data warehouse layers
-- Idempotent: Yes (CREATE SCHEMA IF NOT EXISTS)
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- RAW Layer: Landing zone for source data with minimal transformation
-- Contains exact copies of source parquet files plus audit columns
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS ev_charging_raw
OPTIONS (
  location = 'US',
  description = 'Raw landing zone for EV charging source data. Contains unmodified source records with audit metadata columns (_ingested_at, _source_file).'
);

-- -----------------------------------------------------------------------------
-- STAGING Layer: Cleaned, validated, and standardized data
-- Handles duplicate flags, type casting, nullable preservation, and mapping
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS ev_charging_staging
OPTIONS (
  location = 'US',
  description = 'Staging layer with cleaned, deduplicated, and standardized EV charging data. Includes validation flags, English translations, and rejected records.'
);

-- -----------------------------------------------------------------------------
-- CORE Layer: Star schema dimensional model
-- Dimension and fact tables for analytical queries
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS ev_charging_core
OPTIONS (
  location = 'US',
  description = 'Core dimensional model (star schema) with dimension tables (station, date, time) and the fact_charging_transaction table for analytical workloads.'
);

-- -----------------------------------------------------------------------------
-- MART Layer: Pre-aggregated business-facing tables
-- Optimized for dashboards and executive reporting
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS ev_charging_mart
OPTIONS (
  location = 'US',
  description = 'Business-facing mart layer with pre-aggregated tables for executive KPIs, hourly demand patterns, station utilization, spatial analysis, and cost breakdowns.'
);

-- -----------------------------------------------------------------------------
-- MONITORING Layer: Data quality and pipeline observability
-- Tracks DQ check results and pipeline execution audit trail
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS ev_charging_monitoring
OPTIONS (
  location = 'US',
  description = 'Data quality monitoring and pipeline observability. Stores DQ check results, summary scores, and pipeline execution audit logs.'
);
