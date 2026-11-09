# Đặc tả dashboard

## Nguồn dữ liệu

Tất cả nguồn là bảng BigQuery trong `ev_charging_mart`. Các bảng đã tổng hợp để thao tác biểu đồ không quét fact table thô.

## Bộ lọc bắt buộc

- `source_month`
- loại trạm khi trường có sẵn
- mã hoặc thành phần grid đã ẩn danh khi phù hợp

## Hợp đồng metric

| Metric | Nguồn | Định nghĩa |
|---|---|---|
| Giao dịch | executive/station/hourly | Đếm phiên hợp lệ, không phải bản sao, có năng lượng khác 0 |
| Năng lượng | executive/station/hourly | Tổng `total_elec_kwh` từ nguồn |
| Tổng phí | executive/station | Tổng tiền điện và phí dịch vụ |
| Thời lượng trung bình | executive/station/hourly | Trung bình `duration_min` từ nguồn |
| Idle duration | CORE-derived | Connection duration trừ active charge duration ước tính |

## Visual QA

Trước khi publish, xác nhận tổng số khớp BigQuery, đơn vị CNY và kWh hiển thị rõ, so sánh tháng dùng cùng định nghĩa, và không hiển thị grid như latitude/longitude. Ghi URL report và cấu hình refresh sau mỗi lần rebuild MART.
