# Kiến trúc nền tảng

## Trách nhiệm của từng lớp

| Lớp | Trách nhiệm | Nguyên tắc |
|---|---|---|
| RAW | Vùng tiếp nhận bất biến | Giữ cột nguồn và lineage; không khử trùng lặp |
| STAGING | Chuẩn hóa và gắn cờ chất lượng | Tạo row hash, đánh dấu bản sao và bản ghi bị loại |
| CORE | Mô hình phân tích dùng chung | Một fact row cho mỗi phiên hợp lệ, không tiêu thụ bằng 0 |
| MART | Tổng hợp cho nghiệp vụ | Tránh quét fact table lặp lại từ dashboard |
| MONITORING | Bằng chứng chất lượng và vận hành | Lưu kết quả từng check và tóm tắt mỗi lần chạy |

## Luồng dữ liệu

Parquet được kiểm tra local trước khi upload lên GCS. BigQuery RAW giữ dữ liệu nguồn cùng `_source_file`, `_source_month` và `_ingested_at`. STAGING đọc RAW để ép kiểu, tạo `source_row_hash` và `is_exact_duplicate`; CORE chỉ nhận dữ liệu hợp lệ; MART phục vụ Looker Studio.

## Reprocessing và tính lặp lại

Các bảng được tạo lại theo source file và pipeline run nên một lần chạy lại cho cùng input sẽ cho cùng logic kết quả. Khi chuyển sang production, cần thêm load manifest gồm filename, checksum, ingestion run và trạng thái để kiểm soát phiên bản trước khi cho phép nạp dữ liệu mới.

## Kiểm soát chi phí

- Load Parquet một lần vào các bảng BigQuery đã có partition.
- Partition fact và staging theo `transaction_date`, cluster theo `station_id`.
- Dashboard chỉ đọc các bảng MART.
- Dùng dry run và luôn lọc partition trước khi chạy truy vấn khám phá.
- Không dùng `SELECT *` trong truy vấn production.
