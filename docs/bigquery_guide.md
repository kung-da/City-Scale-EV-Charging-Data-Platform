# Hướng dẫn triển khai BigQuery

## 1. Tài nguyên bắt buộc

- Một GCP project đã bật billing.
- BigQuery API và Cloud Storage API.
- Một bucket GCS và các dataset BigQuery ở cùng location.
- Quyền tối thiểu: BigQuery Job User, BigQuery Data Editor trên dataset và Storage Object Admin trên bucket.

Trong production, dùng service account với quyền giới hạn. Không commit JSON key; ưu tiên Workload Identity Federation cho GitHub Actions.

## 2. Tạo dataset

Project dùng location `us-central1` cho cả BigQuery datasets và GCS bucket. Nếu đổi region, phải đổi đồng nhất trong `.env`, `config/dev.yaml`, DDL và lệnh chạy:

```powershell
.\scripts\run_bq.ps1 -SqlFile sql\ddl\01_create_datasets.sql
```

Chạy tiếp DDL `02` đến `06` theo thứ tự. DDL định nghĩa contract ổn định; các script transformation mới tạo dữ liệu.

## 3. Upload và nạp dữ liệu RAW

Upload source artifact lên GCS:

```powershell
python -c "from pathlib import Path; from ingestion.upload_gcs import upload_file; print(upload_file('YOUR_BUCKET', Path('data/raw/stations_public.parquet')))"
```

Không nạp Parquet trực tiếp bằng autodetect vào bảng RAW rồi bỏ qua audit columns. Các bảng RAW yêu cầu:

- `_ingested_at`: thời điểm nạp;
- `_source_file`: tên file nguồn;
- `_source_month`: tháng nguồn đối với orders.

Helper `ingestion.load_bigquery.load_parquet` hiện là helper load Parquet tối thiểu với autodetect và mặc định không ghi đè bảng đích (`WRITE_EMPTY`). Nó không tự bổ sung đủ lineage columns của contract RAW. Khi triển khai, hãy load vào bảng tạm rồi `INSERT ... SELECT` sang bảng RAW với metadata, hoặc dùng một job nạp có bước metadata tương đương. Chỉ truyền `overwrite=True` cho bảng tạm khi đã kiểm soát việc chạy lại.

Sau khi nạp, kiểm tra:

```sql
SELECT _source_file, COUNT(*) AS rows
FROM `YOUR_PROJECT.ev_charging_raw.raw_orders_2025_01`
GROUP BY _source_file;
```

## 4. Chạy ELT

```powershell
.\scripts\run_bq.ps1 -SqlFile sql\staging\01_build_staging.sql
.\scripts\run_bq.ps1 -SqlFile sql\core\01_build_core.sql
.\scripts\run_bq.ps1 -SqlFile sql\marts\01_build_marts.sql
.\scripts\run_bq.ps1 -SqlFile sql\monitoring\01_run_dq_checks.sql
```

Thứ tự bắt buộc là RAW → STAGING → CORE → MART → MONITORING. Không chạy dashboard trước khi MONITORING hoàn tất.

## 5. Kiểm tra sau khi chạy

```sql
SELECT source_month, COUNT(*) AS rows
FROM `YOUR_PROJECT.ev_charging_core.fact_charging_transaction`
GROUP BY source_month
ORDER BY source_month;

SELECT *
FROM `YOUR_PROJECT.ev_charging_monitoring.dq_summary`
ORDER BY run_timestamp DESC;
```

Đối chiếu số dòng nguồn theo tháng, kiểm tra foreign key station và xác nhận `overall_status` trước khi publish dashboard.

## 6. Theo dõi Free Tier và chi phí

Chạy báo cáo storage/query usage ở cùng location:

```powershell
.\scripts\run_bq.ps1 -SqlFile sql\monitoring\02_free_tier_usage.sql -MaximumBytesBilled 10GB
gcloud storage du -s gs://$env:EV_GCS_BUCKET
```

Theo dõi tham khảo: 10 GiB BigQuery storage, 1 TiB BigQuery query processing và 5 GB-tháng Regional Standard Cloud Storage tại `us-central1`. BigQuery Sandbox có thể không cần billing account nhưng có giới hạn vòng đời; dùng GCS có thể vẫn yêu cầu billing. Đây không phải cam kết `$0`; xác nhận bằng Billing Reports và điều kiện tài khoản thực tế.

## 7. Ước tính chi phí

```powershell
bq query --use_legacy_sql=false --dry_run --format=prettyjson "SELECT COUNT(*) FROM \`YOUR_PROJECT.ev_charging_core.fact_charging_transaction\` WHERE transaction_date BETWEEN '2025-01-01' AND '2025-01-31'"
```

Luôn lọc `transaction_date` khi đọc bảng partitioned. Tránh `SELECT *`, xem bytes processed trong dry run và để Looker Studio đọc MART thay vì fact table. `scripts/run_bq.ps1` áp dụng `--maximum_bytes_billed=500GB` cho mỗi job; giới hạn này không thay thế monthly budget alert.
