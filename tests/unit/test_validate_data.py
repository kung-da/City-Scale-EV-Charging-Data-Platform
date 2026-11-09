import pandas as pd

from ingestion.validate_data import ORDER_COLUMNS, validate_frames


def _orders(**overrides: object) -> pd.DataFrame:
    values = {
        "transaction_date": [pd.Timestamp("2025-01-01")],
        "equipment_classification": ["直流设备"],
        "rated_gun_power_kw": [60.0],
        "station_id": ["ST_1"],
        "pile_id": ["PL_1"],
        "duration_min": [30.0],
        "charge_start_time": [pd.Timestamp("2025-01-01 10:00")],
        "charge_end_time": [pd.Timestamp("2025-01-01 10:30")],
        "total_elec_kwh": [20.0],
        "total_elec_fee": [10.0],
        "total_service_fee": [2.0],
        "total_fee": [12.0],
    }
    values.update(overrides)
    return pd.DataFrame(values, columns=ORDER_COLUMNS)


def _stations() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "station_id": ["ST_1"],
            "dc_piles_num": [1],
            "ac_piles_num": [1],
            "piles_num": [2],
            "dc_charging_gun_num": [1],
            "ac_charging_gun_num": [1],
            "charging_gun_num": [2],
        }
    )


def test_validate_frames_accepts_valid_fixture() -> None:
    result = validate_frames(_stations(), {"orders_2025-01_public.parquet": _orders()})

    assert result["station_rows"] == 1
    assert result["orders"]["orders_2025-01_public.parquet"]["orphan_station_rows"] == 0
    assert result["orders"]["orders_2025-01_public.parquet"]["schema_matches"] is True


def test_validate_frames_reports_quality_failures() -> None:
    orders = pd.concat(
        [
            _orders(),
            _orders(station_id=["MISSING"], total_elec_kwh=[0.0]),
            _orders(duration_min=[-1.0]),
        ],
        ignore_index=True,
    )

    result = validate_frames(_stations(), {"orders_2025-01_public.parquet": orders})
    checks = result["orders"]["orders_2025-01_public.parquet"]

    assert checks["orphan_station_rows"] == 1
    assert checks["zero_energy_rows"] == 1
    assert checks["negative_measure_rows"] == 1
