# City-Scale EV Charging Data Platform

Nền tảng dữ liệu end-to-end cho dữ liệu trạm sạc xe điện công cộng tại Bắc Kinh. Repository này dùng Python để kiểm tra dữ liệu Parquet, Google Cloud Storage để lưu source artifact, BigQuery để xây dựng mô hình ELT nhiều lớp và Looker Studio để tạo dashboard.

## 1. Kết quả sau khi chạy xong

Pipeline tạo các lớp sau trong BigQuery:

```text
Parquet → GCS → RAW → STAGING → CORE → MART → MONITORING → Looker Studio
```

| Dataset | Nội dung |
|---|---|
| `ev_charging_raw` | Bản sao nguồn, giữ lineage và không khử trùng lặp |
| `ev_charging_staging` | Chuẩn hóa kiểu dữ liệu, row hash, cờ chất lượng và duplicate |
| `ev_charging_core` | Star schema gồm dimensions và fact giao dịch |
| `ev_charging_mart` | KPI, nhu cầu theo giờ, utilization theo trạm và tổng hợp theo grid |
| `ev_charging_monitoring` | Kết quả data quality và audit pipeline |

Các bảng MART dùng để kết nối Looker Studio:

- `mart_executive_kpi`
- `mart_hourly_demand`
- `mart_station_utilization`
- `mart_spatial_grid_summary`
- `mart_cost_analysis`

## 2. Dữ liệu nguồn

Nguồn là bộ dữ liệu công khai trên [Figshare](https://figshare.com/articles/dataset/_b_A_city-scale_dataset_of_public_electric_vehicle_charging_transactions_and_infrastructure_b_/31952289), được phát hành theo CC BY 4.0. Đặt ba file sau vào [data/raw/](data/raw/):

| Tệp | Số dòng |
|---|---:|
| `stations_public.parquet` | 8.553 |
| `orders_2025-01_public.parquet` | 2.137.234 |
| `orders_2025-07_public.parquet` | 6.407.461 |

Dữ liệu chỉ bao phủ tháng 01 và tháng 07 năm 2025. Nguồn không có transaction ID; pipeline tạo `source_row_hash` trong STAGING để nhận diện bản ghi trùng tuyệt đối.

> **Lưu ý bản quyền:** thư mục `data/` bị Git ignore để tránh commit file Parquet. Không phân phối lại source artifact nếu chưa kiểm tra yêu cầu ghi công và điều khoản CC BY 4.0.

## 3. Yêu cầu môi trường

### Local

- Windows PowerShell
- Python 3.10+
- Git
- Google Cloud CLI (`gcloud`, `bq`)
- Một GCP project đã bật billing

### Google Cloud

Bật các API:

```powershell
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com
```

Tài khoản chạy pipeline cần tối thiểu:

- BigQuery Job User ở project.
- BigQuery Data Editor trên các dataset.
- Storage Object Admin trên bucket.

## 4. Cài đặt và kiểm tra local

Chạy tại thư mục gốc repository:

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Nếu PowerShell chặn activate script:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.venv\Scripts\Activate.ps1
```

Kiểm tra dữ liệu nguồn:

```powershell
python -m ingestion.main inspect --data-dir data\raw
python -m ingestion.main validate --data-dir data\raw
pytest -q
```

Kết quả validation cần có:

- 8.553 station rows.
- 2.137.234 order rows tháng 01.
- 6.407.461 order rows tháng 07.
- Không có orphan `station_id`.

CLI hiện hỗ trợ hai lệnh `inspect` và `validate`; nó chưa tự động tải file, upload GCS hoặc chạy toàn bộ BigQuery pipeline.

## 5. Cấu hình GCP và biến môi trường

Đăng nhập:

```powershell
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

Tạo bucket ở cùng location với BigQuery. Project này dùng `us-central1` để phù hợp với mục tiêu Free Tier:

```powershell
gsutil mb -p YOUR_PROJECT_ID -l us-central1 gs://YOUR_UNIQUE_BUCKET
```

Copy file mẫu và thiết lập biến trong PowerShell. File `.env` chỉ để tham khảo cấu hình; code hiện tại đọc biến môi trường của process, không tự load `.env`.

```powershell
Copy-Item .env.example .env
$env:EV_PROJECT_ID = "YOUR_PROJECT_ID"
$env:EV_BQ_LOCATION = "us-central1"
$env:EV_GCS_BUCKET = "YOUR_UNIQUE_BUCKET"
$env:EV_DATA_DIR = "data/raw"
```

Kiểm tra project đang dùng:

```powershell
gcloud config get-value project
gcloud auth application-default print-access-token | Out-Null
```

## 6. Upload Parquet lên GCS

Upload từng file bằng helper có sẵn:

```powershell
python -c "from pathlib import Path; from ingestion.upload_gcs import upload_file; print(upload_file($env:EV_GCS_BUCKET, Path('data/raw/stations_public.parquet')))"
python -c "from pathlib import Path; from ingestion.upload_gcs import upload_file; print(upload_file($env:EV_GCS_BUCKET, Path('data/raw/orders_2025-01_public.parquet')))"
python -c "from pathlib import Path; from ingestion.upload_gcs import upload_file; print(upload_file($env:EV_GCS_BUCKET, Path('data/raw/orders_2025-07_public.parquet')))"
```

Xác nhận object đã có:

```powershell
gsutil ls gs://$env:EV_GCS_BUCKET/raw/
```

## 7. Tạo BigQuery datasets và table contracts

Các file DDL dùng location `us-central1`. BigQuery datasets và GCS bucket phải cùng location.

Chạy theo đúng thứ tự:

```powershell
.\scripts\run_bq.ps1 -SqlFile sql\ddl\01_create_datasets.sql
.\scripts\run_bq.ps1 -SqlFile sql\ddl\02_create_raw_tables.sql
.\scripts\run_bq.ps1 -SqlFile sql\ddl\03_create_staging_tables.sql
.\scripts\run_bq.ps1 -SqlFile sql\ddl\04_create_core_tables.sql
.\scripts\run_bq.ps1 -SqlFile sql\ddl\05_create_mart_tables.sql
.\scripts\run_bq.ps1 -SqlFile sql\ddl\06_create_monitoring_tables.sql
```

Các DDL dùng `CREATE TABLE IF NOT EXISTS` nên chạy lại không xóa dữ liệu. Các script transformation dùng `CREATE OR REPLACE TABLE` có chủ đích để rebuild kết quả; chỉ chạy khi cần refresh.

## 8. Nạp RAW có lineage

Không nạp Parquet trực tiếp bằng autodetect vào bảng RAW chính vì các bảng RAW yêu cầu thêm `_ingested_at`, `_source_file` và `_source_month`. Hãy load vào bảng tạm, sau đó insert sang RAW bằng metadata.

### 8.1. Load vào bảng tạm

```powershell
$project = $env:EV_PROJECT_ID
$location = $env:EV_BQ_LOCATION
$bucket = $env:EV_GCS_BUCKET

bq load --project_id=$project --location=$location --replace --autodetect --source_format=PARQUET `
  "${project}:ev_charging_raw._load_stations" `
  "gs://${bucket}/raw/stations_public.parquet"

bq load --project_id=$project --location=$location --replace --autodetect --source_format=PARQUET `
  "${project}:ev_charging_raw._load_orders_2025_01" `
  "gs://${bucket}/raw/orders_2025-01_public.parquet"

bq load --project_id=$project --location=$location --replace --autodetect --source_format=PARQUET `
  "${project}:ev_charging_raw._load_orders_2025_07" `
  "gs://${bucket}/raw/orders_2025-07_public.parquet"
```

### 8.2. Publish vào bảng RAW chính

Chạy script publish để thay thế từng bảng RAW từ bảng tạm một cách nhất quán. Script dùng `CREATE OR REPLACE TABLE`, nên rerun không append duplicate; chỉ chạy sau khi cả ba bảng tạm đã load thành công:

```powershell
.\scripts\run_bq.ps1 -SqlFile sql\ingestion\01_publish_raw.sql
```

Nếu script publish fail, bảng RAW cũ vẫn được giữ cho tới statement tương ứng; không chạy STAGING khi chưa kiểm tra đủ ba source file.

Kiểm tra RAW:

```sql
SELECT _source_file, COUNT(*) AS row_count
FROM `YOUR_PROJECT_ID.ev_charging_raw.raw_stations`
GROUP BY _source_file;

SELECT _source_month, _source_file, COUNT(*) AS row_count
FROM `YOUR_PROJECT_ID.ev_charging_raw.raw_orders_2025_01`
GROUP BY _source_month, _source_file;

SELECT _source_month, _source_file, COUNT(*) AS row_count
FROM `YOUR_PROJECT_ID.ev_charging_raw.raw_orders_2025_07`
GROUP BY _source_month, _source_file;
```

Expected counts là 8.553, 2.137.234 và 6.407.461.

## 9. Chạy pipeline ELT

Chạy lần lượt RAW → STAGING → CORE → MART → MONITORING:

```powershell
.\scripts\run_bq.ps1 -SqlFile sql\staging\01_build_staging.sql
.\scripts\run_bq.ps1 -SqlFile sql\core\01_build_core.sql
.\scripts\run_bq.ps1 -SqlFile sql\marts\01_build_marts.sql
.\scripts\run_bq.ps1 -SqlFile sql\monitoring\01_run_dq_checks.sql
```

`scripts/run_bq.ps1` đặt location và `--maximum_bytes_billed=10GB` cho mỗi query. Đây là giới hạn từng job, không phải giới hạn tổng usage theo tháng; có thể tăng có chủ đích bằng `-MaximumBytesBilled`.

## 10. Kiểm tra sau pipeline

### Reconcile số dòng

```sql
SELECT source_month, COUNT(*) AS fact_rows
FROM `YOUR_PROJECT_ID.ev_charging_core.fact_charging_transaction`
GROUP BY source_month
ORDER BY source_month;
```

Fact rows sẽ nhỏ hơn RAW vì CORE loại bản ghi duplicate, bản ghi invalid và phiên có năng lượng bằng 0.

### Kiểm tra DQ

```sql
SELECT *
FROM `YOUR_PROJECT_ID.ev_charging_monitoring.dq_summary`
ORDER BY run_timestamp DESC;

SELECT *
FROM `YOUR_PROJECT_ID.ev_charging_monitoring.dq_results`
ORDER BY check_timestamp DESC;
```

Không publish dashboard nếu DQ không đạt hoặc số liệu MART không reconcile với CORE.

### Kiểm tra bảng MART

```sql
SELECT * FROM `YOUR_PROJECT_ID.ev_charging_mart.mart_executive_kpi`;
SELECT COUNT(*) FROM `YOUR_PROJECT_ID.ev_charging_mart.mart_hourly_demand`;
SELECT COUNT(*) FROM `YOUR_PROJECT_ID.ev_charging_mart.mart_station_utilization`;
SELECT COUNT(*) FROM `YOUR_PROJECT_ID.ev_charging_mart.mart_spatial_grid_summary`;
```

## 11. Kiểm soát Free Tier và chi phí

Các ngưỡng tham khảo cần theo dõi theo tháng là:

| Dịch vụ | Ngưỡng tham khảo | Cách kiểm tra |
|---|---:|---|
| BigQuery storage | 10 GiB | `sql/monitoring/02_free_tier_usage.sql` |
| BigQuery query processing | 1 TiB | `sql/monitoring/02_free_tier_usage.sql` |
| Cloud Storage | 5 GB-tháng Regional Standard tại `us-central1` | `gcloud storage du -s gs://BUCKET` |

BigQuery Sandbox có thể dùng BigQuery mà không cần thẻ nhưng có giới hạn vòng đời bảng; project này dùng GCS nên có thể vẫn cần billing account. Các ngưỡng Free Tier và điều kiện áp dụng có thể thay đổi. Không coi các con số trên là cam kết `$0`; Billing Reports của project là nguồn xác nhận cuối cùng.

Chạy báo cáo usage:

```powershell
.\scripts\run_bq.ps1 -SqlFile sql\monitoring\02_free_tier_usage.sql -MaximumBytesBilled 10GB
gcloud storage du -s gs://$env:EV_GCS_BUCKET
```

Luôn dry run trước truy vấn lớn:

```powershell
bq query --use_legacy_sql=false --dry_run --format=prettyjson `
  "SELECT COUNT(*) FROM \`$env:EV_PROJECT_ID.ev_charging_core.fact_charging_transaction\` WHERE transaction_date BETWEEN '2025-01-01' AND '2025-01-31'"
```

Nguyên tắc:

- Luôn lọc `transaction_date` khi đọc bảng partitioned.
- Không dùng `SELECT *` trong truy vấn production.
- Dùng `scripts/run_bq.ps1` thay vì gọi `bq query` trực tiếp để có `--maximum_bytes_billed`.
- Chỉ rebuild STAGING/CORE/MART khi RAW đã thay đổi.
- Kết nối Looker Studio với MART, không kết nối trực tiếp fact table.
- Tạo Billing budget alert ở mức `$1`, `$5` và `$10`. Budget alert chỉ cảnh báo, không tự dừng chi phí.
- Trong Google Cloud Console → IAM & Admin → Quotas, lọc BigQuery và đặt custom `Query usage per day` ở mức phù hợp với thử nghiệm. Đây là quota theo ngày, khác với 1 TiB Free Tier theo tháng và khác với `maximum_bytes_billed` theo từng job.
- Xóa bảng tạm `_load_*` sau khi xác nhận RAW:

```powershell
bq rm -f -t "${project}:ev_charging_raw._load_stations"
bq rm -f -t "${project}:ev_charging_raw._load_orders_2025_01"
bq rm -f -t "${project}:ev_charging_raw._load_orders_2025_07"
```

### Dọn tài nguyên sau khi thử nghiệm

Các lệnh dưới đây là destructive; kiểm tra project và bucket trước khi chạy:

```powershell
$project = $env:EV_PROJECT_ID
bq rm -r -f -d "${project}:ev_charging_monitoring"
bq rm -r -f -d "${project}:ev_charging_mart"
bq rm -r -f -d "${project}:ev_charging_core"
bq rm -r -f -d "${project}:ev_charging_staging"
bq rm -r -f -d "${project}:ev_charging_raw"
gcloud storage rm --recursive "gs://$env:EV_GCS_BUCKET"
```

Sau khi dọn, kiểm tra Billing → Reports và Billing → Cost table.

## 12. Kết nối Looker Studio

1. Mở Looker Studio và chọn **Create → Report**.
2. Chọn connector **BigQuery**.
3. Chọn project → dataset `ev_charging_mart`.
4. Tạo data source cho bốn bảng MART.
5. Định dạng tiền tệ là CNY, năng lượng là kWh.
6. Thêm filter `source_month` và filter loại trạm khi có trường tương ứng.
7. Kiểm tra tổng giao dịch, tổng năng lượng và tổng phí khớp với BigQuery.

Chi tiết bố cục dashboard nằm trong [docs/dashboard_guide.md](docs/dashboard_guide.md) và [dashboards/dashboard_specification.md](dashboards/dashboard_specification.md).

## 13. Cấu trúc repository

```text
config/                 Cấu hình development
data/raw/               Parquet source artifact, bị Git ignore
data_quality/           Thư mục cho checks và reports
docs/                   Kiến trúc, BigQuery, data dictionary, dashboard
ingestion/              Inspect, validate, upload GCS và helper BigQuery
sql/ddl/                Tạo dataset và table contracts
sql/staging/            Chuẩn hóa và gắn cờ dữ liệu
sql/core/               Xây dựng star schema
sql/marts/              Xây dựng bảng phục vụ dashboard
sql/monitoring/         Chạy data quality checks
scripts/run_bq.ps1      Chạy query với location và maximum bytes billed
tests/                  Unit và integration tests
```

## 14. Quy tắc metric và giới hạn dữ liệu

- Giao dịch trong CORE/MART không bao gồm bản sao trùng tuyệt đối và phiên có năng lượng bằng 0.
- `total_fee` là tổng tiền điện và phí dịch vụ, không phải lợi nhuận nhà vận hành.
- `estimated_active_charge_min` là ước tính dựa trên hiệu suất 0,9; có thể null khi thiếu công suất định mức.
- `geocoding`, `grid_x` và `grid_y` là mã grid ẩn danh, không phải latitude/longitude.
- Utilization là proxy dựa trên số phiên trên mỗi súng trong mỗi ngày hoạt động, không phải công suất điện đo được.
- Dữ liệu không có vehicle ID, source transaction ID hoặc tọa độ chính xác.

## 15. Tài liệu tham khảo

- [docs/architecture.md](docs/architecture.md): kiến trúc và nguyên tắc vận hành.
- [docs/bigquery_guide.md](docs/bigquery_guide.md): triển khai BigQuery và kiểm soát chi phí.
- [docs/data_dictionary.md](docs/data_dictionary.md): schema, profiling và metric.
- [docs/dashboard_guide.md](docs/dashboard_guide.md): xây dựng Looker Studio.
- [dashboards/dashboard_specification.md](dashboards/dashboard_specification.md): dashboard contract và visual QA.
- [data/README.md](data/README.md): provenance dữ liệu nguồn.
