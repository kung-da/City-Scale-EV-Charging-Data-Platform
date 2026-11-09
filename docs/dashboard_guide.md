# Looker Studio / Data Studio guide

## Connect

1. Open Looker Studio and choose **Create > Report**.
2. Choose the **BigQuery** connector.
3. Select the GCP project, dataset `ev_charging_mart`, and one MART table.
4. Use **Owner's credentials** only when approved by the project owner; otherwise use viewer credentials with least privilege.
5. Set currency to CNY and energy to kWh in field formatting.

Create separate data sources for:

- `mart_executive_kpi`
- `mart_hourly_demand`
- `mart_station_utilization`
- `mart_spatial_grid_summary`

Do not connect the dashboard to RAW or CORE transaction facts for normal charts.

## Pages

### Executive overview

Use scorecards for total transactions, total energy, total fees, average duration, active stations, and average energy/session. Use `source_month` as a comparison filter. Add a monthly KPI table and a fee composition chart from a blended or calculated source.

### Charging demand

Use `mart_hourly_demand` for transactions and energy by hour. Add `source_month`, `time_period`, and `tou_category` controls. Use the percentage field only with its documented denominator.

### Infrastructure

Use `mart_station_utilization` for station type, installed power, charging guns, and station demand. Use `mart_spatial_grid_summary` for anonymized grid heatmaps; label grid fields as anonymized grid components, not latitude/longitude.

### Cost and operations

Use total fee and average fee per session from the executive/station marts. Treat idle duration and active charge duration as estimates, not measured telemetry.

## Reproducibility

Record the report URL, data-source project/dataset/table IDs, extract refresh settings, and calculated fields in the dashboard specification. Refresh after each MART rebuild. Avoid extract caching for rapidly changing production data; for this static portfolio dataset, a scheduled extract is acceptable.
