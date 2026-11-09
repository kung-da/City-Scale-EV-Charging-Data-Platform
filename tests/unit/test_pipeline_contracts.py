from pathlib import Path


ROOT = Path(__file__).parents[2]


def read_sql(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def test_raw_publish_is_replace_based_and_preflights_inputs() -> None:
    sql = read_sql("sql/ingestion/01_publish_raw.sql")

    assert sql.count("CREATE OR REPLACE TABLE") == 3
    assert sql.count("ASSERT") >= 5
    assert "INSERT INTO" not in sql


def test_mart_rebuilds_are_deterministic_and_include_declared_marts() -> None:
    sql = read_sql("sql/marts/01_build_marts.sql")
    ddl = read_sql("sql/ddl/05_create_mart_tables.sql")

    for table in (
        "mart_executive_kpi",
        "mart_hourly_demand",
        "mart_station_utilization",
        "mart_spatial_grid_summary",
        "mart_cost_analysis",
    ):
        assert f"ev_charging_mart.{table}" in sql
        assert f"ev_charging_mart.{table}" in ddl

    assert "INSERT INTO" not in sql
    assert "pct_of_month_transactions" in sql
    assert "d.transaction_count AS total_transactions" in sql


def test_dq_handles_empty_tables_and_checks_reconciliation() -> None:
    sql = read_sql("sql/monitoring/01_run_dq_checks.sql")

    assert "COALESCE(SAFE_DIVIDE(records_failed, records_checked), 0)" in sql
    assert "staging_january_row_reconciliation" in sql
    assert "staging_july_row_reconciliation" in sql
    assert "check_passed" in sql
