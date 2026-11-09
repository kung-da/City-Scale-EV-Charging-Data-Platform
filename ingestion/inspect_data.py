"""Source-file inspection without mutating source data."""

from pathlib import Path
from typing import Any

def inspect_parquet(path: Path) -> dict[str, Any]:
    import pyarrow.parquet as pq

    parquet = pq.ParquetFile(path)
    schema = parquet.schema_arrow
    return {
        "file": path.name,
        "bytes": path.stat().st_size,
        "rows": parquet.metadata.num_rows,
        "columns": len(schema),
        "schema": {field.name: str(field.type) for field in schema},
        "row_groups": parquet.num_row_groups,
    }


def inspect_directory(directory: Path) -> list[dict[str, Any]]:
    return [inspect_parquet(path) for path in sorted(directory.glob("*.parquet"))]
