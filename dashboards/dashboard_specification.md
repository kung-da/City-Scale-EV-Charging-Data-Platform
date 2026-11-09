# Dashboard specification

## Data sources

All sources are BigQuery tables in `ev_charging_mart`. Tables are pre-aggregated so chart interactions do not scan the raw fact table.

## Required filters

- `source_month`
- station type where available
- anonymized grid code/components where relevant

## Metric contract

| Metric | Source | Definition |
|---|---|---|
| Transactions | executive/station/hourly | Count of canonical valid non-zero sessions |
| Energy | executive/station/hourly | Sum of source `total_elec_kwh` |
| Total fees | executive/station | Sum of electricity and service fees |
| Average duration | executive/station/hourly | Mean source `duration_min` |
| Idle duration | CORE-derived | Connection duration minus estimated active charge duration |

## Visual QA

Before publishing, verify that totals reconcile to BigQuery, CNY and kWh units are shown, monthly comparisons use the same definitions, and no grid value is rendered as a map latitude/longitude.
