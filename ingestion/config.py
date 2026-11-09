"""Environment-backed pipeline configuration."""

from dataclasses import dataclass
import os
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    project_id: str | None
    location: str
    gcs_bucket: str | None
    data_dir: Path
    source_item_url: str


def load_settings() -> Settings:
    return Settings(
        project_id=os.getenv("EV_PROJECT_ID"),
        location=os.getenv("EV_BQ_LOCATION", "US"),
        gcs_bucket=os.getenv("EV_GCS_BUCKET"),
        data_dir=Path(os.getenv("EV_DATA_DIR", "data/raw")),
        source_item_url=os.getenv(
            "EV_SOURCE_ITEM_URL",
            "https://figshare.com/articles/dataset/_b_A_city-scale_dataset_of_public_electric_vehicle_charging_transactions_and_infrastructure_b_/31952289",
        ),
    )
