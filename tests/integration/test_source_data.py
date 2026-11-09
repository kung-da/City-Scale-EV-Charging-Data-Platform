from pathlib import Path

import pytest

from ingestion.inspect_data import inspect_directory
from ingestion.validate_data import validate_source_directory


DATA_DIR = Path(__file__).parents[2] / "data" / "raw"
REQUIRED_FILES = {
    "stations_public.parquet",
    "orders_2025-01_public.parquet",
    "orders_2025-07_public.parquet",
}

pytestmark = pytest.mark.integration


def _require_source_data() -> None:
    if not DATA_DIR.exists() or not REQUIRED_FILES.issubset(
        {path.name for path in DATA_DIR.glob("*.parquet")}
    ):
        pytest.skip("Released Parquet artifacts are required for integration tests")
    try:
        import pyarrow.parquet  # noqa: F401
    except ImportError as exc:
        pytest.skip(f"PyArrow is unavailable for integration tests: {exc}")


def test_source_files_are_inspectable() -> None:
    _require_source_data()
    assert {item["file"] for item in inspect_directory(DATA_DIR)} >= REQUIRED_FILES


def test_released_data_quality_baseline() -> None:
    _require_source_data()
    result = validate_source_directory(DATA_DIR)
    assert result["station_rows"] == 8553
    assert result["station_id_duplicates"] == 0
    assert result["orders"]["orders_2025-01_public.parquet"]["rows"] == 2137234
    assert result["orders"]["orders_2025-07_public.parquet"]["rows"] == 6407461
    assert all(item["orphan_station_rows"] == 0 for item in result["orders"].values())
