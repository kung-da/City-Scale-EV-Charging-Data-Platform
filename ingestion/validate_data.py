"""Local data-quality checks for the released Parquet files."""

from pathlib import Path
from typing import Any

import pandas as pd
import pyarrow.parquet as pq

ORDER_COLUMNS = [
    "transaction_date",
    "equipment_classification",
    "rated_gun_power_kw",
    "station_id",
    "pile_id",
    "duration_min",
    "charge_start_time",
    "charge_end_time",
    "total_elec_kwh",
    "total_elec_fee",
    "total_service_fee",
    "total_fee",
]


def validate_source_directory(directory: Path) -> dict[str, Any]:
    stations = pq.read_table(directory / "stations_public.parquet").to_pandas()
    station_ids = set(stations["station_id"])
    result: dict[str, Any] = {
        "station_rows": len(stations),
        "station_id_duplicates": int(stations["station_id"].duplicated().sum()),
        "station_component_mismatches": int(
            (stations["dc_piles_num"] + stations["ac_piles_num"] != stations["piles_num"]).sum()
        ),
        "gun_component_mismatches": int(
            (stations["dc_charging_gun_num"] + stations["ac_charging_gun_num"] != stations["charging_gun_num"]).sum()
        ),
        "orders": {},
    }
    for path in sorted(directory.glob("orders_*.parquet")):
        orders = pq.read_table(path).to_pandas()
        result["orders"][path.name] = {
            "rows": len(orders),
            "exact_duplicate_rows": int(orders.duplicated().sum()),
            "orphan_station_rows": int((~orders["station_id"].isin(station_ids)).sum()),
            "zero_energy_rows": int((orders["total_elec_kwh"] == 0).sum()),
            "negative_measure_rows": int(
                (orders[["duration_min", "total_elec_kwh", "total_elec_fee", "total_service_fee", "total_fee"]] < 0)
                .any(axis=1)
                .sum()
            ),
            "end_before_start_rows": int(
                (orders["charge_end_time"] < orders["charge_start_time"]).sum()
            ),
            "schema_matches": list(orders.columns) == ORDER_COLUMNS,
        }
    return result
