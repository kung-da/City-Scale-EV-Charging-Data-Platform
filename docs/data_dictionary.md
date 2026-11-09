# EV Charging Intelligence — Data Dictionary & Profiling Report

## 1. Dataset Provenance & Overview

- **Source Paper**: *"A city-scale dataset of public electric vehicle charging transactions and infrastructure"* (*Scientific Data*, Nature Portfolio, 2026; DOI: [10.1038/s41597-026-07918-5](https://doi.org/10.1038/s41597-026-07918-5)).
- **Repository**: Figshare Item `31952289` (DOI: `10.6084/m9.figshare.31952289`).
- **Location & Scope**: Beijing, China (all administrative districts), covering public charging infrastructure and transactions in January 2025 and July 2025.
- **License**: CC BY 4.0 International (Attribution Required).

### Verified Source Files Summary
| File Name | Size (Bytes) | Size (MB) | Row Count | Column Count | File Format |
|---|---:|---:|---:|---:|---|
| `stations_public.parquet` | 150,533 | 0.14 MB | 8,553 | 10 | Apache Parquet |
| `orders_2025-01_public.parquet` | 58,178,602 | 55.48 MB | 2,137,234 | 12 | Apache Parquet |
| `orders_2025-07_public.parquet` | 189,701,623 | 180.91 MB | 6,407,461 | 12 | Apache Parquet |
| **Total Orders (Jan + Jul)** | **247,880,225** | **236.39 MB** | **8,544,695** | **12** | Apache Parquet |

---

## 2. Table Schemas & Data Dictionaries

### 2.1. Infrastructure Table: `stations_public.parquet`
- **Granularity**: 1 row per charging station (`station_id`).
- **Total Rows**: 8,553.
- **Primary Key**: `station_id` (Unique: 8,553, Nulls: 0).

| Column Name | Arrow Type | Pandas Type | Null Count (%) | Unique Values | Description & Verified Value Examples |
|---|---|---|---|---|---|
| `station_id` | string | str | 0 (0.00%) | 8,553 | Unique station identifier (`ST_000001` - `ST_008553`). Primary Key. |
| `geocoding` | string | str | 0 (0.00%) | 2,636 | Anonymized 1 km × 1 km planar spatial grid index (`<grid_x>_<grid_y>`, e.g., `9891_4446`). |
| `construction_site` | string | str | 0 (0.00%) | 17 | Land-use classification / site scenario in Chinese (e.g., `居住区`, `写字楼`, `工业园区`). |
| `station_total_power_kw` | double | float64 | 0 (0.00%) | 760 | Total installed charging station capacity in kW (Mean: 497.92 kW, Min: 3.5 kW, Max: 36,000 kW). |
| `piles_num` | double | float64 | 0 (0.00%) | 114 | Total count of charging piles/posts (Mean: 9.14, Min: 1, Max: 400). |
| `dc_piles_num` | double | float64 | 0 (0.00%) | 57 | Total count of DC fast charging piles (Mean: 3.46, Min: 0, Max: 180). |
| `ac_piles_num` | double | float64 | 0 (0.00%) | 105 | Total count of AC slow charging piles (Mean: 5.70, Min: 0, Max: 400). |
| `charging_gun_num` | double | float64 | 0 (0.00%) | 120 | Total count of charging connectors/guns (Mean: 11.50, Min: 1, Max: 400). |
| `dc_charging_gun_num` | double | float64 | 0 (0.00%) | 71 | Total count of DC fast charging connectors (Mean: 5.44, Min: 0, Max: 180). |
| `ac_charging_gun_num` | double | float64 | 0 (0.00%) | 106 | Total count of AC slow charging connectors (Mean: 6.09, Min: 0, Max: 400). |

#### Verified Construction Site Translation (`construction_site`)
| Chinese Name | English Standard Name | Station Count | Order Count Impact |
|---|---|---:|---|
| `大型建筑配建停车场` | Parking facilities for large buildings | 2,427 | High |
| `居住区` | Residential areas | 2,126 | High |
| `写字楼` | Office buildings | 1,235 | High |
| `其他` | Other | 812 | Medium |
| `工业园区` | Industrial parks | 647 | Medium |
| `公共机构` | Public institutions | 425 | Low |
| `大型文体设施` | Large cultural & sports venues | 224 | Low |
| `交通枢纽` | Transportation hubs | 179 | High per-charger |
| `居民区` | Residential areas (synonym) | 148 | Consolidate with `居住区` |
| `城市绿地` | Urban green spaces | 103 | Low |
| `加油加气站` | Fuel & gas stations | 99 | High turnover |
| `风景区` | Scenic areas | 63 | Low |
| `路边停车位` | On-street parking | 26 | Medium |
| `企事业单位` | Enterprises & institutions | 22 | Low |
| `公交场站` | Bus stations | 13 | High power |
| `城际高速服务区` | Intercity highway service areas | 3 | High power |
| `出租车` | Taxi dedicated station | 1 | High turnover |

---

### 2.2. Transaction Tables: `orders_2025-01_public.parquet` & `orders_2025-07_public.parquet`
- **Granularity**: 1 row per charging session transaction event.
- **Total Records**: 2,137,234 (Jan) + 6,407,461 (Jul) = 8,544,695.
- **Source transaction identifier**: None is provided. The pipeline must generate a deterministic row hash from all source columns and retain the source file/month. This is a technical lineage key, not a source business ID.
- **Duplicate policy**: Preserve all rows in RAW and STAGING. STAGING marks one canonical occurrence and flags later exact duplicates; CORE excludes the flagged copies and invalid rows. January has 1 duplicate row and July has 3,406 duplicate rows.

| Column Name | Arrow Type | Pandas Type | Jan Nulls (%) | Jul Nulls (%) | Description & Domain Rules |
|---|---|---|---|---|---|
| `transaction_date` | date32[day] | datetime/date | 0 (0.00%) | 0 (0.00%) | Calendar date of transaction (`YYYY-MM-DD`). The released Parquet files store this as a native date, not a string. |
| `equipment_classification` | string | str | 1,179 (0.055%) | 0 (0.00%) | Charger class: `直流设备` (DC Fast) vs `交流设备` (AC Slow). |
| `rated_gun_power_kw` | double | float64 | 1,179 (0.055%) | 0 (0.00%) | Nameplate rated power of charging gun in kW (e.g., 7 kW, 60 kW, 120 kW). |
| `station_id` | string | str | 0 (0.00%) | 0 (0.00%) | Foreign Key to `stations_public.station_id`. |
| `pile_id` | string | str | 0 (0.00%) | 0 (0.00%) | Anonymized physical charging pile identifier (`PL_XXXXXX`). |
| `duration_min` | double | float64 | 0 (0.00%) | 0 (0.00%) | Recorded connection/charging duration in minutes. |
| `charge_start_time` | timestamp | datetime64[ns] | 0 (0.00%) | 0 (0.00%) | Exact plug-in & session start timestamp. |
| `charge_end_time` | timestamp | datetime64[ns] | 0 (0.00%) | 0 (0.00%) | Exact plug-out & session completion timestamp. |
| `total_elec_kwh` | double | float64 | 0 (0.00%) | 0 (0.00%) | Delivered electrical energy in kilowatt-hours (kWh). |
| `total_elec_fee` | double | float64 | 0 (0.00%) | 0 (0.00%) | Raw electricity consumption cost in CNY (元). |
| `total_service_fee` | double | float64 | 0 (0.00%) | 0 (0.00%) | Operator charging service fee in CNY (元). |
| `total_fee` | double | float64 | 0 (0.00%) | 0 (0.00%) | Total fee paid (`total_elec_fee + total_service_fee`) in CNY (元). |

---

## 3. Relational Referential Integrity Analysis

1. **Foreign Key Integrity**:
   - Distinct stations in `stations_public`: **8,553**
   - Distinct stations in `orders_2025-01`: **6,246** (100.0% join match with stations)
   - Distinct stations in `orders_2025-07`: **7,972** (100.0% join match with stations)
   - **Orphan Station IDs in Orders**: **0 records (0.00%)**.
2. **Pile Cardinality**:
   - Stations have multiple piles (`pile_id`), and piles support 1 or 2 charging guns (`dc_charging_gun_num`, `ac_charging_gun_num`).
3. **Temporal Linkage**:
   - `transaction_date` connects to calendar date dimension (`dim_date`).
   - `charge_start_time` connects to time-of-day dimension (`dim_time`).

## 4. Verified Profiling Findings and Design Consequences

These checks were run against the local Parquet files and are design constraints:

| Check | January 2025 | July 2025 | Design consequence |
|---|---:|---:|---|
| Rows | 2,137,234 | 6,407,461 | Reconcile each source month separately. |
| Exact duplicate rows | 1 | 3,406 | Do not deduplicate RAW; canonicalize only in STAGING/CORE and audit removals. |
| Null equipment classification | 1,179 | 0 | Keep nullable; do not infer a class from unavailable pile metadata. |
| Null rated gun power | 1,179 | 0 | Keep nullable; active-charge estimates remain nullable when power is absent. |
| Zero-energy rows | 34,551 | 792 | Flag separately; exclude from energy/session KPI facts only by documented rule. |
| Negative duration/energy/fees | 0 | 0 | Keep as validity checks for future loads. |
| End before start | 0 | 0 | Timestamp ordering check passes on the released files. |
| Duration mismatch over 1 minute | 0 | 0 | Recorded duration agrees with timestamps under this tolerance. |
| Timestamp/date boundary cases | Jan end reaches 2025-02-01; Jul start reaches 2025-06-30 | - | Partition by `transaction_date`; retain both timestamps and validate cross-month boundaries. |
| Orphan station rows | 0 | 0 | Station foreign-key validation passes. |
| `dc_piles_num + ac_piles_num != piles_num` | 41 stations | - | Station-quality warning; do not reject the station. |
| `dc_charging_gun_num + ac_charging_gun_num != charging_gun_num` | 42 stations | - | Station-quality warning; do not reject the station. |

The station `geocoding` values are anonymized grid codes such as `9891_4446`, not geographic coordinates. The platform may split the code into `grid_x` and `grid_y` for grouping, but must not present them as longitude/latitude or derive precise locations.
