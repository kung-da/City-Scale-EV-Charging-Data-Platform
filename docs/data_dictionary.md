# Data Dictionary và báo cáo profiling

## 1. Nguồn và phạm vi dữ liệu

- **Bài báo nguồn:** *A city-scale dataset of public electric vehicle charging transactions and infrastructure* (*Scientific Data*, Nature Portfolio, 2026; DOI: [10.1038/s41597-026-07918-5](https://doi.org/10.1038/s41597-026-07918-5)).
- **Kho dữ liệu:** Figshare item `31952289` (DOI: `10.6084/m9.figshare.31952289`).
- **Phạm vi:** Bắc Kinh, Trung Quốc; hạ tầng và giao dịch sạc công cộng trong tháng 01 và tháng 07 năm 2025.
- **Giấy phép:** CC BY 4.0 International, bắt buộc ghi công.

### Tóm tắt các file đã kiểm chứng

| Tệp | Kích thước | Số dòng | Số cột | Định dạng |
|---|---:|---:|---:|---|
| `stations_public.parquet` | 0,14 MB | 8.553 | 10 | Apache Parquet |
| `orders_2025-01_public.parquet` | 55,48 MB | 2.137.234 | 12 | Apache Parquet |
| `orders_2025-07_public.parquet` | 180,91 MB | 6.407.461 | 12 | Apache Parquet |
| **Tổng orders** | **236,39 MB** | **8.544.695** | **12** | Apache Parquet |

## 2. Schema và từ điển dữ liệu

### 2.1. Bảng hạ tầng `stations_public.parquet`

- **Grain:** một dòng cho mỗi trạm (`station_id`).
- **Số dòng:** 8.553.
- **Khóa chính:** `station_id` (8.553 giá trị duy nhất, không null).

| Cột | Kiểu Arrow | Kiểu Pandas | Null | Mô tả |
|---|---|---|---:|---|
| `station_id` | string | str | 0 | ID trạm duy nhất, từ `ST_000001` đến `ST_008553`. |
| `geocoding` | string | str | 0 | Mã lưới không gian ẩn danh 1 km × 1 km, ví dụ `9891_4446`; không phải tọa độ. |
| `construction_site` | string | str | 0 | Phân loại địa điểm bằng tiếng Trung, gồm 17 nhóm. |
| `station_total_power_kw` | double | float64 | 0 | Tổng công suất lắp đặt của trạm, đơn vị kW. |
| `piles_num` | double | float64 | 0 | Tổng số cọc/thiết bị sạc. |
| `dc_piles_num` | double | float64 | 0 | Số thiết bị sạc DC. |
| `ac_piles_num` | double | float64 | 0 | Số thiết bị sạc AC. |
| `charging_gun_num` | double | float64 | 0 | Tổng số súng/đầu nối sạc. |
| `dc_charging_gun_num` | double | float64 | 0 | Số súng sạc DC. |
| `ac_charging_gun_num` | double | float64 | 0 | Số súng sạc AC. |

Pipeline chuẩn hóa `construction_site` sang `construction_site_en` và gộp `居住区` cùng `居民区` thành `Residential areas`. Các giá trị grid được tách thành `grid_x` và `grid_y` chỉ để nhóm và tổng hợp.

### 2.2. Bảng giao dịch orders

Hai file orders có grain là **một dòng cho mỗi phiên sạc**:

| Cột | Kiểu nguồn | Null tháng 01 | Null tháng 07 | Mô tả |
|---|---|---:|---:|---|
| `transaction_date` | date32[day] | 0 | 0 | Ngày giao dịch, được lưu dạng DATE. |
| `equipment_classification` | string | 1.179 | 0 | `直流设备` (DC) hoặc `交流设备` (AC). |
| `rated_gun_power_kw` | double | 1.179 | 0 | Công suất định mức của súng, kW. |
| `station_id` | string | 0 | 0 | Khóa liên kết tới bảng trạm. |
| `pile_id` | string | 0 | 0 | ID ẩn danh của cọc sạc. |
| `duration_min` | double | 0 | 0 | Thời lượng kết nối, phút. |
| `charge_start_time` | timestamp | 0 | 0 | Thời điểm bắt đầu phiên. |
| `charge_end_time` | timestamp | 0 | 0 | Thời điểm kết thúc phiên. |
| `total_elec_kwh` | double | 0 | 0 | Điện năng tiêu thụ, kWh. |
| `total_elec_fee` | double | 0 | 0 | Tiền điện, CNY. |
| `total_service_fee` | double | 0 | 0 | Phí dịch vụ, CNY. |
| `total_fee` | double | 0 | 0 | Tổng phí (`total_elec_fee + total_service_fee`), CNY. |

Nguồn không có transaction ID. Pipeline tạo `source_row_hash` xác định từ toàn bộ cột nguồn và giữ `source_month` cùng tên file. Đây là khóa lineage kỹ thuật, không phải business ID từ nguồn.

### Chính sách bản sao và bản ghi đặc biệt

- RAW giữ nguyên tất cả dòng.
- STAGING đánh dấu một lần xuất hiện canonical và các bản sao trùng tuyệt đối.
- CORE loại bản sao bị đánh dấu, bản ghi lỗi và phiên có năng lượng bằng 0.
- Tháng 01 có 1 bản sao; tháng 07 có 3.406 bản sao.
- Có 1.179 dòng tháng 01 thiếu loại thiết bị và công suất định mức; không suy diễn loại thiết bị khi nguồn không cung cấp.

## 3. Phân tích liên kết

- 8.553 trạm trong bảng hạ tầng.
- 6.246 trạm xuất hiện trong orders tháng 01 và 7.972 trạm trong tháng 07.
- Tỷ lệ join với bảng trạm là 100%; không có orphan station ID.
- Một trạm có thể có nhiều cọc (`pile_id`) và cọc có thể hỗ trợ một hoặc hai súng sạc.
- `transaction_date` liên kết với `dim_date`; giờ của `charge_start_time` liên kết với `dim_time`.

## 4. Phát hiện profiling và hệ quả thiết kế

| Kiểm tra | Tháng 01/2025 | Tháng 07/2025 | Hệ quả |
|---|---:|---:|---|
| Số dòng | 2.137.234 | 6.407.461 | Reconcile riêng từng tháng. |
| Bản sao trùng tuyệt đối | 1 | 3.406 | Không khử ở RAW; canonicalize ở STAGING/CORE và audit. |
| Thiếu loại thiết bị | 1.179 | 0 | Giữ null; không suy diễn. |
| Thiếu công suất định mức | 1.179 | 0 | Ước tính active charge có thể null. |
| Năng lượng bằng 0 | 34.551 | 792 | Gắn cờ; loại khỏi KPI theo chính sách đã công bố. |
| Giá trị âm | 0 | 0 | Giữ kiểm tra cho các lần nạp sau. |
| End trước start | 0 | 0 | Kiểm tra thứ tự timestamp đạt. |
| Sai lệch duration quá 1 phút | 0 | 0 | Duration khớp timestamp trong ngưỡng. |
| Trường hợp qua ranh giới tháng | Cuối phiên tháng 01 tới 01/02 | Phiên bắt đầu từ 30/06 | Partition theo `transaction_date`, vẫn giữ hai timestamp. |
| Orphan station rows | 0 | 0 | Kiểm tra foreign key đạt. |
| Thành phần pile không khớp tổng | 41 trạm | - | Cảnh báo chất lượng, không loại trạm. |
| Thành phần gun không khớp tổng | 42 trạm | - | Cảnh báo chất lượng, không loại trạm. |

`geocoding` chỉ là mã grid ẩn danh như `9891_4446`, không phải kinh độ/vĩ độ. Có thể tách mã thành `grid_x`, `grid_y` để nhóm dữ liệu, nhưng không được hiển thị như tọa độ hoặc suy ra vị trí chính xác.
