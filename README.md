# City-Scale EV Charging Data Platform

## Portfolio case study

Đây là một dự án portfolio về xây dựng nền tảng dữ liệu cho hoạt động sạc xe điện công cộng tại Bắc Kinh. Mục tiêu của dự án là thể hiện đầy đủ quy trình **data engineering end-to-end**: kiểm tra dữ liệu nguồn, nạp dữ liệu lên Google Cloud, mô hình hóa trong BigQuery, kiểm tra chất lượng dữ liệu và tạo các bảng tổng hợp cho dashboard.

> **Trạng thái:** cấu trúc SQL, mô hình dữ liệu và tài liệu đã sẵn sàng để bắt đầu triển khai BigQuery. Phần nạp RAW cần tuân theo hướng dẫn lineage trong [docs/bigquery_guide.md](docs/bigquery_guide.md), không tải trực tiếp bằng autodetect rồi bỏ qua các cột audit.

## Câu chuyện dữ liệu

Nguồn dữ liệu là bộ Parquet công khai từ Figshare, gồm hạ tầng trạm sạc và các phiên sạc trong tháng 01 và tháng 07 năm 2025:

| Tệp | Số dòng |
|---|---:|
| `stations_public.parquet` | 8.553 |
| `orders_2025-01_public.parquet` | 2.137.234 |
| `orders_2025-07_public.parquet` | 6.407.461 |

Nguồn không có transaction ID. Vì vậy, pipeline giữ nguyên dữ liệu trong RAW, tạo row hash xác định trong STAGING, đánh dấu bản sao trùng tuyệt đối và chỉ đưa bản ghi hợp lệ, không tiêu thụ điện bằng 0 vào fact table.

## Kiến trúc

```text
Figshare Parquet
      |
      v
Python inspect/validate ---> GCS raw/
      |
      v
BigQuery RAW       (dữ liệu nguồn + lineage)
      |
      v
STAGING            (ép kiểu, row hash, cờ chất lượng, khử trùng lặp)
      |
      v
CORE               (star schema)
      |
      v
MART               (bảng tổng hợp cho dashboard)
      |
      v
Looker Studio
```

| Lớp | Vai trò |
|---|---|
| RAW | Bất biến, giữ nguyên dữ liệu nguồn và metadata nạp |
| STAGING | Chuẩn hóa kiểu dữ liệu, đánh dấu lỗi và bản sao |
| CORE | Mô hình phân tích tái sử dụng: dimensions và fact |
| MART | Tổng hợp theo KPI, giờ, trạm và lưới không gian |
| MONITORING | Kết quả kiểm tra chất lượng và nhật ký chạy pipeline |

## Điểm thể hiện năng lực trong portfolio

- Thiết kế ELT nhiều lớp trên BigQuery thay vì biến đổi trực tiếp dữ liệu nguồn.
- Xử lý dữ liệu không có khóa nghiệp vụ bằng deterministic row hash.
- Bảo toàn lineage và khả năng truy vết bản ghi bị loại.
- Partition theo `transaction_date`, cluster theo `station_id` để kiểm soát chi phí.
- Xây dựng star schema và các mart phục vụ Looker Studio.
- Định nghĩa rõ metric, giả định và giới hạn của dữ liệu.

## Lộ trình chạy dự án

### 1. Chuẩn bị môi trường local

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m ingestion.main inspect --data-dir data\raw
python -m ingestion.main validate --data-dir data\raw
pytest -q
```

Các file Parquet không được CI tải tự động. Không phân phối lại dữ liệu nếu chưa kiểm tra yêu cầu ghi công của giấy phép CC BY 4.0.

### 2. Chuẩn bị Google Cloud

```powershell
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

Điền các biến trong [.env.example](.env.example): project, region, bucket và thư mục dữ liệu. Bật BigQuery API và Cloud Storage API; tạo bucket và dataset trong cùng một location.

### 3. Tạo dataset và hợp đồng bảng

Chạy [sql/ddl/01_create_datasets.sql](sql/ddl/01_create_datasets.sql), sau đó chạy các file DDL `02` đến `06` theo thứ tự. Nếu không dùng `US`, thay location trong file tạo dataset trước khi chạy.

### 4. Nạp RAW có lineage

Upload Parquet lên GCS, sau đó nạp vào các bảng RAW theo hướng dẫn ở [docs/bigquery_guide.md](docs/bigquery_guide.md). Bắt buộc giữ `_source_file`, `_source_month` và `_ingested_at`; đây là điều kiện để các truy vấn STAGING chạy đúng.

### 5. Chạy ELT

```powershell
Get-Content sql\staging\01_build_staging.sql | bq query --use_legacy_sql=false
Get-Content sql\core\01_build_core.sql | bq query --use_legacy_sql=false
Get-Content sql\marts\01_build_marts.sql | bq query --use_legacy_sql=false
Get-Content sql\monitoring\01_run_dq_checks.sql | bq query --use_legacy_sql=false
```

### 6. Kiểm tra và kể câu chuyện dữ liệu

Đối chiếu số dòng theo tháng, tỷ lệ bản ghi hợp lệ và kết quả DQ trong dataset MONITORING. Sau đó kết nối Looker Studio chỉ với các bảng MART theo [docs/dashboard_guide.md](docs/dashboard_guide.md).

## Tài liệu dự án

- [docs/architecture.md](docs/architecture.md): nguyên tắc kiến trúc và vận hành.
- [docs/bigquery_guide.md](docs/bigquery_guide.md): triển khai BigQuery, nạp RAW và kiểm soát chi phí.
- [docs/data_dictionary.md](docs/data_dictionary.md): nguồn, schema, metric và các phát hiện profiling.
- [docs/dashboard_guide.md](docs/dashboard_guide.md): xây dựng dashboard trên Looker Studio.
- [dashboards/dashboard_specification.md](dashboards/dashboard_specification.md): hợp đồng nguồn dữ liệu và kiểm thử trực quan.
- [data/README.md](data/README.md): provenance và quy tắc lưu dữ liệu.

## Định nghĩa metric quan trọng

- Đếm giao dịch trong CORE/MART loại bản sao trùng tuyệt đối và phiên có năng lượng bằng 0.
- Phí được báo cáo riêng theo tiền điện, phí dịch vụ và tổng phí; không gọi là lợi nhuận.
- `estimated_active_charge_min` là ước tính dựa trên giả định hiệu suất 0,9 và có thể null khi thiếu công suất định mức.
- Giá trị grid là mã không gian đã ẩn danh, không phải kinh độ/vĩ độ.

## Giới hạn và hướng phát triển

Dữ liệu chỉ gồm tháng 01 và tháng 07 năm 2025, không có vehicle ID, transaction ID nguồn hoặc tọa độ chính xác. Chỉ số utilization là proxy dựa trên số phiên trên mỗi súng sạc trong mỗi ngày hoạt động, không phải công suất điện đo được.

Các bước phát triển tiếp theo cho portfolio:

1. Thêm load manifest gồm filename, checksum và ingestion run.
2. Tự động hóa orchestration và ghi `pipeline_audit`.
3. Mở rộng dữ liệu theo tháng để phân tích mùa vụ.
4. Thêm CI kiểm tra SQL và kiểm tra reconciliation sau mỗi lần build MART.
