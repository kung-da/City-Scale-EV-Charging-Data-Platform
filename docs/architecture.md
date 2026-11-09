# Architecture

## Layer responsibilities

| Layer | Responsibility | Rule |
|---|---|---|
| RAW | Immutable source landing | Preserve source columns and lineage; no deduplication |
| STAGING | Type normalization and quality flags | Canonicalize exact duplicates and audit exclusions |
| CORE | Reusable analytical model | One fact row per canonical valid non-zero session |
| MART | Dashboard-oriented aggregates | Avoid repeated scans of the fact table |
| MONITORING | Quality and execution evidence | Store every check result and run summary |

## Reprocessing

Loads are idempotent by source file and table replacement. A rerun replaces the corresponding raw table and rebuilds downstream tables from the source. For production history, use a load manifest keyed by source filename, checksum, and ingestion run before allowing a new version.

## Cost controls

- Parquet is loaded once into partitioned BigQuery tables.
- Fact and staging tables are partitioned by `transaction_date` and clustered by `station_id`.
- Looker Studio reads MART tables.
- Use BigQuery dry runs and date predicates before executing exploratory queries.
