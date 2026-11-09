# EV Charging Intelligence - City-Scale Data Platform

Production-minded ELT demo for Beijing public EV charging data from Figshare. The platform preserves Parquet source files, validates them, loads BigQuery layers, builds a star schema, and publishes dashboard-ready marts for Looker Studio.

## What is included

- Source profiling and verified data dictionary.
- Python inspection, validation, GCS upload, and BigQuery load helpers.
- BigQuery RAW, STAGING, CORE, MART, and MONITORING SQL.
- Exact-duplicate auditing and rejected-record traceability.
- Dimensional model with station, date, time, and charging transaction fact tables.
- Pre-aggregated executive, hourly, station, and spatial marts.
- Unit tests and GitHub Actions CI.

## Verified source

The local source files are:

| File | Rows |
|---|---:|
| `stations_public.parquet` | 8,553 |
| `orders_2025-01_public.parquet` | 2,137,234 |
| `orders_2025-07_public.parquet` | 6,407,461 |

The source has no transaction ID. RAW preserves all rows; STAGING canonicalizes exact duplicates using a deterministic row hash and records the duplicate policy. See [docs/data_dictionary.md](docs/data_dictionary.md).

## Local quick start

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m ingestion.main inspect --data-dir data\raw
python -m ingestion.main validate --data-dir data\raw
pytest -q
```

The Parquet files are not downloaded by CI and should not be redistributed without checking the CC BY 4.0 attribution and source terms.

## BigQuery deployment

1. Install the Google Cloud CLI and authenticate with Application Default Credentials:

   ```powershell
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. Set environment variables from `.env.example`.
3. Run [sql/ddl/01_create_datasets.sql](sql/ddl/01_create_datasets.sql), then the remaining DDL scripts in numeric order.
4. Upload files to GCS or load local Parquet with the Python helper. The raw tables should retain `_source_file`, `_source_month`, and `_ingested_at`.
5. Run, in order:

   - `sql/staging/01_build_staging.sql`
   - `sql/core/01_build_core.sql`
   - `sql/marts/01_build_marts.sql`
   - `sql/monitoring/01_run_dq_checks.sql`

Detailed commands, IAM, cost controls, and dry-run guidance are in [docs/bigquery_guide.md](docs/bigquery_guide.md).

## Looker Studio

Connect Looker Studio to the MART tables, not raw transaction tables. The required pages, fields, filters, and chart definitions are in [docs/dashboard_guide.md](docs/dashboard_guide.md) and [dashboards/dashboard_specification.md](dashboards/dashboard_specification.md).

## Architecture

```text
Figshare Parquet
      |
      v
Python inspect/validate ---> immutable GCS raw/
      |
      v
BigQuery RAW (source shape + lineage)
      |
      v
STAGING (typed, hashed, deduplicated, flagged)
      |
      v
CORE (star schema)
      |
      v
MART (Looker Studio aggregates)
      |
      v
Looker Studio dashboards
```

## Important metric definitions

- Transaction counts in CORE/MART exclude exact duplicate copies and zero-energy sessions.
- Fees are reported as source electricity fee, service fee, and total fee; they are not labelled operator profit.
- `estimated_active_charge_min` uses the documented 0.9 efficiency assumption and is nullable when rated power is missing.
- Grid values are anonymized codes, not coordinates.

## Limitations

The dataset covers January and July 2025 only, does not include vehicle identifiers, and does not provide a source transaction ID or precise coordinates. Utilization is a proxy based on sessions per installed gun per active day, not measured electrical capacity utilization.
