"""Upload immutable source artifacts to Google Cloud Storage."""

from pathlib import Path


def upload_file(bucket_name: str, source: Path, object_name: str | None = None) -> str:
    from google.cloud import storage

    client = storage.Client()
    blob = client.bucket(bucket_name).blob(object_name or f"raw/{source.name}")
    blob.upload_from_filename(str(source))
    return f"gs://{bucket_name}/{blob.name}"
