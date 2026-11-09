from pathlib import Path

from ingestion.inspect_data import inspect_directory
from ingestion.validate_data import validate_source_directory


DATA_DIR = Path(__file__).parents[2] / "data" / "raw"


def test_source_files_are_inspectable() -> None:
    files = inspect_directory(DATA_DIR)
    assert {item["file"] for item in files} >= {
        "stations_public.parquet",
        "orders_2025-01_public.parquet",
        "orders_2025-07_public.parquet",
    }


def test_released_data_quality_baseline() -> None:
    result = validate_source_directory(DATA_DIR)
    assert result["station_rows"] == 8553
    assert result["station_id_duplicates"] == 0
    assert result["orders"]["orders_2025-01_public.parquet"]["rows"] == 2137234
    assert result["orders"]["orders_2025-07_public.parquet"]["rows"] == 6407461
    assert all(item["orphan_station_rows"] == 0 for item in result["orders"].values())
