-- ==============================================================================
-- EV Charging Intelligence Platform - Mart Layer Table Definitions
-- Description: Pre-aggregated business-facing tables optimized for dashboards
--              and executive reporting
-- Idempotent: Yes (CREATE TABLE IF NOT EXISTS). Transformation is separate.
-- ==============================================================================

-- -----------------------------------------------------------------------------
-- mart_executive_kpi: Monthly executive-level KPIs
-- Grain: One row per month
-- Purpose: High-level dashboard cards comparing Jan vs Jul performance
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_mart.mart_executive_kpi (
  -- Dimensions
  source_month                STRING    NOT NULL OPTIONS (description = 'Month identifier: "2025-01" or "2025-07"'),
  month_name                  STRING    NOT NULL OPTIONS (description = 'Human-readable month name (e.g., "January 2025")'),

  -- Volume KPIs
  total_transactions          INT64     NOT NULL OPTIONS (description = 'Total number of valid charging sessions'),
  total_energy_kwh            FLOAT64   OPTIONS (description = 'Total electricity consumed across all sessions in kWh'),
  total_revenue_cny           FLOAT64   OPTIONS (description = 'Total revenue (elec fee + service fee) in CNY'),

  -- Efficiency KPIs
  avg_duration_min            FLOAT64   OPTIONS (description = 'Average session duration in minutes'),
  avg_energy_per_session_kwh  FLOAT64   OPTIONS (description = 'Average energy consumed per session in kWh'),
  avg_fee_per_session_cny     FLOAT64   OPTIONS (description = 'Average total fee per session in CNY'),
  avg_fee_per_kwh_cny         FLOAT64   OPTIONS (description = 'Average total fee per kWh in CNY'),

  -- Coverage KPIs
  active_stations             INT64     OPTIONS (description = 'Count of distinct stations with at least one transaction'),
  active_piles                INT64     OPTIONS (description = 'Count of distinct piles with at least one transaction'),
  avg_transactions_per_station FLOAT64  OPTIONS (description = 'Average transactions per active station'),

  -- DC/AC split
  dc_transaction_pct          FLOAT64   OPTIONS (description = 'Percentage of transactions using DC equipment'),
  dc_energy_pct               FLOAT64   OPTIONS (description = 'Percentage of total energy from DC equipment'),

  -- Audit
  _computed_at                TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when KPIs were computed')
)
OPTIONS (
  description = 'Executive KPI summary by month. Compares January (winter) vs July (summer) across volume, efficiency, coverage, and DC/AC split metrics.'
);

-- -----------------------------------------------------------------------------
-- mart_hourly_demand: Hourly charging demand patterns
-- Grain: One row per hour per month
-- Purpose: Time-of-day demand curves for capacity planning
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_mart.mart_hourly_demand (
  -- Dimensions
  source_month                STRING    NOT NULL OPTIONS (description = 'Month identifier'),
  hour_of_day                 INT64     NOT NULL OPTIONS (description = 'Hour of day (0-23)'),
  time_period                 STRING    OPTIONS (description = 'Time period: Morning/Afternoon/Evening/Night'),
  tou_category                STRING    OPTIONS (description = 'TOU pricing tier: Valley/Flat/Peak/Spike'),

  -- Measures
  transaction_count           INT64     NOT NULL OPTIONS (description = 'Number of sessions starting in this hour'),
  avg_energy_kwh              FLOAT64   OPTIONS (description = 'Average energy per session in kWh'),
  total_energy_kwh            FLOAT64   OPTIONS (description = 'Total energy consumed in sessions starting this hour'),
  avg_duration_min            FLOAT64   OPTIONS (description = 'Average session duration in minutes'),
  avg_fee_cny                 FLOAT64   OPTIONS (description = 'Average total fee per session in CNY'),
  pct_of_month_transactions   FLOAT64   OPTIONS (description = 'Percentage of monthly transactions occurring in this hour'),

  -- Audit
  _computed_at                TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when metrics were computed')
)
OPTIONS (
  description = 'Hourly demand patterns by month. Shows transaction volume, energy, and fee distributions across 24 hours with TOU pricing tier alignment.'
);

-- -----------------------------------------------------------------------------
-- mart_station_utilization: Per-station utilization metrics
-- Grain: One row per station per month
-- Purpose: Station-level performance and utilization analysis
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_mart.mart_station_utilization (
  -- Dimensions
  station_id                  STRING    NOT NULL OPTIONS (description = 'Station identifier'),
  source_month                STRING    NOT NULL OPTIONS (description = 'Month identifier'),
  construction_site_en        STRING    OPTIONS (description = 'English site type'),
  grid_x                      INT64     OPTIONS (description = 'Anonymized grid component; not longitude'),
  grid_y                      INT64     OPTIONS (description = 'Anonymized grid component; not latitude'),

  -- Infrastructure context
  station_total_power_kw      FLOAT64   OPTIONS (description = 'Total installed power capacity'),
  charging_gun_num            INT64     OPTIONS (description = 'Total number of charging guns'),

  -- Volume metrics
  total_transactions          INT64     NOT NULL OPTIONS (description = 'Total charging sessions'),
  total_energy_kwh            FLOAT64   OPTIONS (description = 'Total energy consumed in kWh'),
  total_revenue_cny           FLOAT64   OPTIONS (description = 'Total revenue in CNY'),

  -- Duration metrics
  avg_duration_min            FLOAT64   OPTIONS (description = 'Average session duration'),
  avg_energy_per_session_kwh  FLOAT64   OPTIONS (description = 'Average energy per session'),

  -- DC/AC split
  dc_transactions             INT64     OPTIONS (description = 'Number of DC sessions'),
  ac_transactions             INT64     OPTIONS (description = 'Number of AC sessions'),
  dc_energy_kwh               FLOAT64   OPTIONS (description = 'Total DC energy consumed'),
  ac_energy_kwh               FLOAT64   OPTIONS (description = 'Total AC energy consumed'),

  -- Utilization estimates
  active_days                 INT64     OPTIONS (description = 'Number of distinct days with at least one session'),
  transactions_per_gun_per_day FLOAT64  OPTIONS (description = 'Avg daily transactions per charging gun (utilization proxy)'),
  energy_per_gun_per_day_kwh  FLOAT64   OPTIONS (description = 'Avg daily energy per charging gun in kWh'),

  -- Audit
  _computed_at                TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when metrics were computed')
)
OPTIONS (
  description = 'Station-level utilization metrics by month. Includes volume, DC/AC split, and utilization estimates per charging gun for capacity planning.'
);

-- -----------------------------------------------------------------------------
-- mart_spatial_grid_summary: Grid cell-level aggregations
-- Grain: One row per grid cell (grid_x, grid_y) per month
-- Purpose: Spatial analysis and heatmap visualization
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_mart.mart_spatial_grid_summary (
  -- Dimensions
  grid_x                      INT64     NOT NULL OPTIONS (description = 'Anonymized grid component; not longitude'),
  grid_y                      INT64     NOT NULL OPTIONS (description = 'Anonymized grid component; not latitude'),
  source_month                STRING    NOT NULL OPTIONS (description = 'Month identifier'),

  -- Station infrastructure in grid cell
  station_count               INT64     OPTIONS (description = 'Number of stations in this grid cell'),
  total_installed_power_kw    FLOAT64   OPTIONS (description = 'Total installed power capacity in grid cell'),
  total_charging_guns         INT64     OPTIONS (description = 'Total charging guns in grid cell'),

  -- Demand metrics
  total_transactions          INT64     OPTIONS (description = 'Total charging sessions in grid cell'),
  total_energy_kwh            FLOAT64   OPTIONS (description = 'Total energy consumed in grid cell'),
  total_revenue_cny           FLOAT64   OPTIONS (description = 'Total revenue in grid cell'),
  avg_energy_per_session_kwh  FLOAT64   OPTIONS (description = 'Average energy per session in grid cell'),
  avg_duration_min            FLOAT64   OPTIONS (description = 'Average session duration in grid cell'),

  -- Dominant site type
  dominant_site_type          STRING    OPTIONS (description = 'Most common construction_site_en in this grid cell'),

  -- Audit
  _computed_at                TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when metrics were computed')
)
OPTIONS (
  description = 'Spatial grid cell summary by month. Aggregates station infrastructure and charging demand at grid-level resolution for heatmap visualization.'
);

-- -----------------------------------------------------------------------------
-- mart_cost_analysis: Fee breakdowns by station type, equipment, and month
-- Grain: One row per construction site type per equipment class per month
-- Purpose: Pricing and revenue analysis across segments
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ev_charging_mart.mart_cost_analysis (
  -- Dimensions
  construction_site_en        STRING    NOT NULL OPTIONS (description = 'English site type'),
  equipment_classification    STRING    OPTIONS (description = 'Equipment type: 直流设备 (DC) or 交流设备 (AC); nullable when the source classification is missing'),
  source_month                STRING    NOT NULL OPTIONS (description = 'Month identifier'),

  -- Volume context
  transaction_count           INT64     NOT NULL OPTIONS (description = 'Number of transactions in this segment'),
  total_energy_kwh            FLOAT64   OPTIONS (description = 'Total energy consumed in this segment'),

  -- Fee totals
  total_elec_fee_cny          FLOAT64   OPTIONS (description = 'Total electricity fees in CNY'),
  total_service_fee_cny       FLOAT64   OPTIONS (description = 'Total service fees in CNY'),
  total_fee_cny               FLOAT64   OPTIONS (description = 'Total fees in CNY'),

  -- Fee averages per session
  avg_elec_fee_per_session    FLOAT64   OPTIONS (description = 'Average electricity fee per session in CNY'),
  avg_service_fee_per_session FLOAT64   OPTIONS (description = 'Average service fee per session in CNY'),
  avg_total_fee_per_session   FLOAT64   OPTIONS (description = 'Average total fee per session in CNY'),

  -- Fee per kWh (unit economics)
  avg_elec_fee_per_kwh        FLOAT64   OPTIONS (description = 'Average electricity fee per kWh in CNY'),
  avg_service_fee_per_kwh     FLOAT64   OPTIONS (description = 'Average service fee per kWh in CNY'),
  avg_total_fee_per_kwh       FLOAT64   OPTIONS (description = 'Average total fee per kWh in CNY'),

  -- Revenue share
  service_fee_pct             FLOAT64   OPTIONS (description = 'Service fee as percentage of total fee'),

  -- Audit
  _computed_at                TIMESTAMP NOT NULL OPTIONS (description = 'Timestamp when metrics were computed')
)
OPTIONS (
  description = 'Cost and fee analysis by site type, equipment classification, and month. Breaks down electricity vs service fees at per-session and per-kWh levels for pricing strategy.'
);
