# HỆ THỐNG QUẢN LÝ NHÀ SÁCH (BOOK STORE MANAGEMENT SYSTEM)

Dự án bài tập lớn / đồ án học phần **Hệ Quản Trị Cơ Sở Dữ Liệu (DBMS330284)**.

---

## 1. TỔNG QUAN DỰ ÁN

Hệ thống được thiết kế theo mô hình kiến trúc **Fat-Database (Logic-in-DB)**:
- **Cơ sở dữ liệu (SQL Server)**: Đóng vai trò hạt nhân trung tâm, chịu trách nhiệm lưu trữ và thực thi 100% quy tắc nghiệp vụ, tính toàn vẹn dữ liệu, kiểm soát đồng thời, phân quyền bảo mật, tự động kích hoạt tính toán và ghi nhật ký kiểm toán.
- **Ứng dụng Web (FastAPI + Jinja2 + Bootstrap 5 + pyodbc)**: Giao diện trực quan cho người dùng cuối. Ứng dụng **tuyệt đối không sử dụng ORM** (chỉ sử dụng truy vấn tham số qua `pyodbc`), **không sử dụng thư viện đồ thị JS** (trình bày số liệu dạng bảng và KPI cards), đóng vai trò nhận tương tác người dùng, gọi trực tiếp các Stored Procedures / Views / Functions và render giao diện HTML.

---

## 2. KIẾN TRÚC & TIÊU CHÍ BAREM CƠ SỞ DỮ LIỆU (5-5-5-5-5)

Toàn bộ kịch bản SQL được lưu trữ tại thư mục `database/` gồm đúng 12 tệp theo quy chuẩn:

| STT | Tệp SQL | Nội Dung & Tiêu Chí Kỹ Thuật |
|:---:|:---|:---|
| 01 | `01_create_database.sql` | Khởi tạo CSDL `BookStore` với collation chuẩn tiếng Việt `Vietnamese_CI_AS`. |
| 02 | `02_create_tables.sql` | Thiết kế 9 bảng chuẩn 3NF: `Genres`, `Author`, `Publisher`, `Employee`, `Customer`, `Book`, `Orders`, `OrderDetails`, `AuditLog`. |
| 03 | `03_sample_data.sql` | Nạp dữ liệu mẫu thực tế: 6 thể loại, 19 tác giả, 5 NXB, 4 nhân viên (mật khẩu hash PBKDF2), 8 khách hàng, 35 đầu sách, 16 hóa đơn mẫu. |
| 04 | `04_constraints.sql` | **21 ràng buộc toàn vẹn**: 8 `CHECK` (giá > 0, tồn >= 0, số lượng > 0, điểm >= 0, regex email/phone), 4 `UNIQUE` (username, email, phone, tên thể loại), 9 `DEFAULT`. |
| 05 | `05_indexes.sql` | **6 chỉ mục Non-Clustered (`IX_`)** tối ưu hiệu năng lọc/tìm kiếm + Script so sánh hiệu năng `SET STATISTICS IO, TIME ON`. |
| 06 | `06_functions.sql` | **5 UDFs**: 3 Scalar Functions (`fn_GetOrderTotal`, `fn_CalculateRewardPoints`, `fn_GetCustomerTier`) + 2 Inline Table-Valued Functions (`fn_GetBooksByGenre`, `fn_GetLowStockBooks`). |
| 07 | `07_views.sql` | **6 Views nghiệp vụ**: `vw_BookCatalog`, `vw_OrderSummary`, `vw_TopSellingBooks`, `vw_MonthlyRevenue`, `vw_CustomerSummary`, `vw_EmployeeInfo`. |
| 08 | `08_procedures.sql` | **6 Stored Procedures nghiệp vụ** (`sp_Login`, `sp_CreateOrder`, `sp_CancelOrder`, `sp_UpdateBookStock`, `sp_SearchBooks`, `sp_GetRevenueReport`) + Toàn bộ SP CRUD chuẩn cho 6 bảng thực thể. |
| 09 | `09_triggers.sql` | **6 Database Triggers**: Tự động trừ tồn kho khi bán, tích lũy điểm thưởng thành viên, hoàn kho và trừ điểm khi hủy đơn, chặn sửa đơn đã hoàn tất, tự động ghi nhật ký `AuditLog` khi sửa giá sách và thông tin nhân viên. |
| 10 | `10_transactions.sql` | **5 kịch bản Giao dịch (Transactions)**: Xử lý giao dịch bán hàng, điều chỉnh kho, bảo vệ tính nhất quán dữ liệu có đầy đủ các nhánh `COMMIT TRAN` và `ROLLBACK TRAN`. |
| 11 | `11_security.sql` | **Phân quyền người dùng (Security)**: Thiết lập 5 Login/User và 5 Database Roles (`role_admin`, `role_manager`, `role_sales`, `role_inventory`, `role_auth`) tuân thủ nguyên tắc đặc quyền tối thiểu (Principle of Least Privilege). |
| 12 | `12_concurrency_demo.sql` | Kịch bản mô phỏng tranh chấp đồng thời: 2 phiên cùng mua cuốn sách cuối cùng, Deadlock, so sánh mức độ cô lập (Isolation Levels) và Backup/Restore CSDL tự động. |

---

## 3. CÁC PHÂN HỆ CHỨC NĂNG ỨNG DỤNG WEB

1. **Xác thực & Phân quyền (Authentication & RBAC)**:
   - Đăng nhập bảo mật bằng cơ chế mã hóa mật khẩu PBKDF2-HMAC-SHA256 (100.000 vòng lặp, salt 16 bytes).
   - Điều hướng động thanh Navigation và kiểm tra quyền hạn chặt chẽ theo vai trò (Role).
2. **Bán hàng tại quầy (POS)**:
   - Giao diện trực quan: Tìm kiếm sách nhanh, lọc sách còn hàng, thêm vào giỏ hàng, điều chỉnh số lượng tự động giới hạn theo tồn kho thực tế.
   - Chọn khách hàng thành viên (hiển thị điểm tích lũy hiện có) hoặc Khách vãng lai.
   - Chọn phương thức thanh toán: Tiền mặt (`Cash`) hoặc Chuyển khoản (`Transfer`).
   - Đóng gói giỏ hàng dạng JSON và gọi Stored Procedure `sp_CreateOrder` trong Transaction; Trigger tự động trừ kho và cộng điểm thưởng.
3. **Quản lý Hóa đơn & Hủy đơn**:
   - Tra cứu, lọc hóa đơn theo mã đơn hàng hoặc trạng thái (`Completed`, `Cancelled`, `Pending`).
   - Xem chi tiết từng hóa đơn, danh sách sách đã mua, thành tiền và điểm thưởng.
   - Hỗ trợ thao tác Hủy hóa đơn (gọi `sp_CancelOrder`): Trigger DB tự động hoàn trả số lượng sách về kho và khấu trừ lại điểm tích lũy.
4. **Quản lý Danh mục Sách & Kho**:
   - Lọc sách theo từ khóa tựa sách/tác giả, lọc theo thể loại, khoảng giá, và trạng thái tồn kho (sử dụng SP `sp_SearchBooks`).
   - Thêm mới, chỉnh sửa thông tin sách, cập nhật số lượng tồn kho.
   - Khi giá sách bị thay đổi, Trigger DB `trg_AuditBookPrice` sẽ tự động bắt sự kiện và ghi lại nhật ký kiểm toán vào bảng `AuditLog`.
5. **Quản lý Thể loại, Tác giả, Nhà xuất bản**:
   - Giao diện CRUD trực quan gọi các Stored Procedures tương ứng.
6. **Quản lý Khách hàng & Thành viên thân thiết**:
   - Tra cứu danh sách khách hàng, số điện thoại, điểm tích lũy.
   - Tự động hiển thị Hạng thành viên (Standard, Silver, Gold, VIP) được tính toán từ Scalar Function `dbo.fn_GetCustomerTier`.
   - Xem trang chi tiết lịch sử mua hàng của từng khách hàng.
7. **Quản trị Nhân viên**:
   - Dành riêng cho `Admin`: Thêm tài khoản nhân viên, đổi vai trò, đổi mật khẩu (tự động hash PBKDF2).
   - Trigger `trg_AuditEmployee` tự động ghi nhận các thay đổi vai trò hoặc tài khoản.
8. **Báo cáo & Thống kê**:
   - **Báo cáo doanh thu**: Lọc theo khoảng ngày tùy chọn (gọi `sp_GetRevenueReport`) và tổng hợp doanh thu theo tháng (từ View `vw_MonthlyRevenue`).
   - **Top sách bán chạy**: Bảng xếp hạng các đầu sách có doanh số và doanh thu cao nhất (từ View `vw_TopSellingBooks`).
   - **Cảnh báo tồn kho thấp**: Tra cứu các đầu sách có lượng tồn &le; ngưỡng quy định (gọi Function `dbo.fn_GetLowStockBooks(@Threshold)`).
   - **Nhật ký kiểm toán (Audit Log)**: Xem lịch sử các thay đổi nhạy cảm (giá sách, nhân viên), thời gian thực hiện và dữ liệu trước/sau thay đổi.

---

## 4. HƯỚNG DẪN CÀI ĐẶT & CHẠY ỨNG DỤNG

### Bước 1: Khởi tạo Cơ Sở Dữ Liệu trên SQL Server
Mở công cụ **SQL Server Management Studio (SSMS)** hoặc công cụ SQL bất kỳ, kết nối tới SQL Server instance của bạn và chạy tuần tự các tệp trong thư mục `database/`:
```text
database/01_create_database.sql
database/02_create_tables.sql
database/03_sample_data.sql
database/04_constraints.sql
database/05_indexes.sql
database/06_functions.sql
database/07_views.sql
database/08_procedures.sql
database/09_triggers.sql
database/10_transactions.sql
database/11_security.sql
database/12_concurrency_demo.sql
```

### Bước 2: Cấu hình Môi trường Ứng dụng
Tạo tệp `.env` tại thư mục gốc của dự án (sao chép từ `.env.example` nếu có):
```ini
DB_SERVER=.\SQLEXPRESS
DB_NAME=BookStore

# Chế độ kết nối: WINDOWS_AUTH (mặc định) hoặc SQL_LOGIN
DB_AUTH_MODE=WINDOWS_AUTH

# Dùng khi chuyển sang DB_AUTH_MODE=SQL_LOGIN
DB_USER=login_auth
DB_PASSWORD=AuthLogin@123

# Khóa bí mật cho Session Cookie
SESSION_SECRET_KEY=bookstore_super_secret_key_dbms_2026
```

### Bước 3: Cài đặt Thư viện Python & Khởi động Web Server
1. Mở terminal hoặc PowerShell tại thư mục dự án:
```powershell
# Kích hoạt môi trường ảo
.\venv\Scripts\Activate.ps1

# Cài đặt các thư viện cần thiết (nếu chưa cài)
pip install -r requirements.txt
```

2. Khởi chạy máy chủ Web FastAPI qua Uvicorn:
```powershell
uvicorn app.main:app --reload --port 8000
```

3. Mở trình duyệt web và truy cập địa chỉ:
```text
http://127.0.0.1:8000
```

---

## 5. TÀI KHOẢN TRẢI NGHIỆM HỆ THỐNG

| Tên Đăng Nhập | Mật Khẩu | Vai Trò (Role) | Quyền Hạn Chính |
|:---|:---|:---:|:---|
| `admin` | `admin123` | **Admin** | Toàn quyền quản trị hệ thống, quản lý nhân viên, xem báo cáo & nhật ký AuditLog. |
| `manager` | `manager123` | **Manager** | Quản lý bán hàng, danh mục sách, đối tác, khách hàng và xem toàn bộ báo cáo doanh số. |
| `sales` | `sales123` | **Sales** | Lập hóa đơn bán hàng POS, xem lịch sử hóa đơn, quản lý thông tin khách hàng. |
| `inventory` | `inventory123` | **Inventory** | Quản lý kho, cập nhật số lượng tồn, quản lý danh mục tác giả, thể loại, NXB. |

---

## 6. KIỂM THỬ HỆ THỐNG (AUTOMATED TESTING)

Để chạy bộ kịch bản kiểm thử tự động toàn diện kiểm tra kết nối CSDL, Stored Procedures, Database Triggers và phân quyền RBAC:
```powershell
python -c "import scratch.test_app; scratch.test_app.run_tests()"
```