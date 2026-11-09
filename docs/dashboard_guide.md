# Hướng dẫn Looker Studio

## Kết nối dữ liệu

1. Mở Looker Studio và chọn **Create > Report**.
2. Chọn connector **BigQuery**.
3. Chọn project, dataset `ev_charging_mart` và một bảng MART.
4. Dùng Owner's credentials chỉ khi được phê duyệt; nếu không, dùng viewer credentials với quyền tối thiểu.
5. Định dạng tiền tệ là CNY và năng lượng là kWh.

Tạo data source riêng cho:

- `mart_executive_kpi`
- `mart_hourly_demand`
- `mart_station_utilization`
- `mart_spatial_grid_summary`

Không kết nối biểu đồ thông thường tới RAW hoặc CORE fact table.

## Các trang đề xuất

### Tổng quan điều hành

Dùng scorecard cho số giao dịch, năng lượng, tổng phí, thời lượng trung bình, số trạm hoạt động và năng lượng trung bình mỗi phiên. Dùng `source_month` để so sánh tháng; biểu đồ cơ cấu phí lấy từ các trường phí đã định nghĩa.

### Nhu cầu sạc

Dùng `mart_hourly_demand` để xem giao dịch và năng lượng theo giờ. Thêm bộ lọc `source_month`, `time_period` và `tou_category`. Chỉ dùng phần trăm theo đúng mẫu số được ghi trong data dictionary.

### Hạ tầng

Dùng `mart_station_utilization` cho loại trạm, công suất lắp đặt, số súng và nhu cầu. Dùng `mart_spatial_grid_summary` cho heatmap lưới đã ẩn danh; không gắn grid với latitude/longitude.

### Chi phí và vận hành

Dùng tổng phí và phí trung bình mỗi phiên từ các MART. Idle duration và active charge duration là số ước tính, không phải telemetry đo trực tiếp.

## Kiểm thử trước khi publish

- Tổng giao dịch và năng lượng khớp với BigQuery.
- Đơn vị CNY và kWh hiển thị rõ.
- So sánh tháng dùng cùng định nghĩa metric.
- Không có giá trị grid nào bị hiển thị như tọa độ.
- Ghi URL report, project/dataset/table IDs, refresh settings và calculated fields vào [dashboards/dashboard_specification.md](../dashboards/dashboard_specification.md).
