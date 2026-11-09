"""BigQuery load helpers for Parquet source files."""

from pathlib import Path


def load_parquet(
    project_id: str,
    dataset: str,
    table: str,
    source: Path,
    location: str = "us-central1",
    overwrite: bool = False,
) -> int:
    """Load a Parquet file without overwriting an existing table by default."""
    from google.cloud import bigquery

    client = bigquery.Client(project=project_id)
    table_id = f"{project_id}.{dataset}.{table}"
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=(
            bigquery.WriteDisposition.WRITE_TRUNCATE
            if overwrite
            else bigquery.WriteDisposition.WRITE_EMPTY
        ),
        autodetect=True,
    )
    with source.open("rb") as stream:
        job = client.load_table_from_file(stream, table_id, job_config=job_config, location=location)
    job.result()
    return client.get_table(table_id).num_rows
