# BigQuery guide

## Required resources

- One GCP project with billing enabled.
- BigQuery API and Cloud Storage API enabled.
- A regional GCS bucket and BigQuery datasets in the same location.
- A user or service account with BigQuery Job User, BigQuery Data Editor on the datasets, and Storage Object Admin on the bucket.

Use a dedicated service account in production. Never commit JSON keys; prefer Workload Identity Federation in GitHub Actions.

## Create datasets

Replace `US` in [sql/ddl/01_create_datasets.sql](../sql/ddl/01_create_datasets.sql) when your bucket uses another location, then run:

```powershell
Get-Content sql\ddl\01_create_datasets.sql | bq query --use_legacy_sql=false
```

Run DDL files `02` through `06` in order. The DDL is descriptive and establishes stable table contracts; the transformation scripts create the populated tables.

## Load source data

```powershell
python -c "from pathlib import Path; from ingestion.upload_gcs import upload_file; print(upload_file('YOUR_BUCKET', Path('data/raw/stations_public.parquet')))"
```

For local development, use `ingestion.load_bigquery.load_parquet`. For production, load from the versioned GCS URI and record the checksum from `data/raw/files_metadata.json`.

The raw load must preserve:

- native `DATE` for `transaction_date`;
- `TIMESTAMP` values without clipping cross-month sessions;
- `_source_file`, `_source_month`, and `_ingested_at`.

## Run ELT

```powershell
Get-Content sql\staging\01_build_staging.sql | bq query --use_legacy_sql=false
Get-Content sql\core\01_build_core.sql | bq query --use_legacy_sql=false
Get-Content sql\marts\01_build_marts.sql | bq query --use_legacy_sql=false
Get-Content sql\monitoring\01_run_dq_checks.sql | bq query --use_legacy_sql=false
```

## Validate and estimate cost

Use the BigQuery UI query validator or CLI dry run:

```powershell
bq query --use_legacy_sql=false --dry_run --format=prettyjson "SELECT * FROM \`YOUR_PROJECT.ev_charging_mart.mart_executive_kpi\`"
```

Avoid `SELECT *` in production and always filter partitioned facts by `transaction_date`. Review bytes processed before running full-period queries.

## Useful checks

```sql
SELECT * FROM `YOUR_PROJECT.ev_charging_monitoring.dq_summary`
ORDER BY run_timestamp DESC;

SELECT source_month, COUNT(*) AS rows
FROM `YOUR_PROJECT.ev_charging_core.fact_charging_transaction`
GROUP BY source_month;
```
