# HỆ THỐNG QUẢN LÝ NHÀ SÁCH (BOOK STORE MANAGEMENT SYSTEM)

Hệ thống quản lý vận hành nội bộ và bán hàng tại quầy (Back-Office & POS) cho chuỗi nhà sách - Học phần **Hệ Quản Trị Cơ Sở Dữ Liệu (DBMS330284)**.

---

## 1. TỔNG QUAN HỆ THỐNG

Hệ thống được thiết kế theo mô hình kiến trúc **Fat-Database (Logic-in-DB)**:
- **Cơ sở dữ liệu (SQL Server)**: Đóng vai trò hạt nhân trung tâm, chịu trách nhiệm lưu trữ và thực thi toàn bộ quy tắc nghiệp vụ, tính toàn vẹn dữ liệu, kiểm soát đồng thời, phân quyền bảo mật theo vai trò, tự động kích hoạt tính toán và ghi nhật ký kiểm toán.
- **Ứng dụng Web (FastAPI + Jinja2 + Bootstrap 5 + pyodbc)**: Giao diện trực quan phục vụ vận hành. Ứng dụng không sử dụng ORM (thực thi truy vấn tham số hóa trực tiếp qua `pyodbc`), không sử dụng thư viện đồ thị client-side (trình bày số liệu dạng bảng và KPI cards), tiếp nhận tương tác người dùng, gọi trực tiếp các Stored Procedures / Views / Functions và kết xuất giao diện HTML Server-Side Rendering (SSR).

---

## 2. KIẾN TRÚC & TIÊU CHÍ KỸ THUẬT CƠ SỞ DỮ LIỆU

Toàn bộ kịch bản SQL được lưu trữ tại thư mục `database/` gồm 12 tệp theo quy chuẩn:

| STT | Tệp SQL | Nội Dung & Tiêu Chí Kỹ Thuật |
|:---:|:---|:---|
| 01 | `01_create_database.sql` | Khởi tạo CSDL `BookStore` với collation chuẩn tiếng Việt `Vietnamese_CI_AS`. |
| 02 | `02_create_tables.sql` | Thiết kế 9 bảng chuẩn 3NF: `Genres`, `Author`, `Publisher`, `Employee`, `Customer`, `Book`, `Orders`, `OrderDetails`, `AuditLog`. |
| 03 | `03_sample_data.sql` | Nạp dữ liệu mẫu thực tế: 6 thể loại, 19 tác giả, 5 NXB, 4 nhân viên (mật khẩu hash PBKDF2), 8 khách hàng, 35 đầu sách, 16 hóa đơn mẫu. |
| 04 | `04_constraints.sql` | **21 ràng buộc toàn vẹn**: 8 `CHECK` (giá > 0, tồn >= 0, số lượng > 0, điểm >= 0, định dạng email/phone), 4 `UNIQUE` (username, email, phone, tên thể loại), 9 `DEFAULT`. |
| 05 | `05_indexes.sql` | **6 chỉ mục Non-Clustered (`IX_`)** tối ưu hiệu năng lọc/tìm kiếm và tổng hợp báo cáo. |
| 06 | `06_functions.sql` | **5 UDFs**: 3 Scalar Functions (`fn_GetOrderTotal`, `fn_CalculateRewardPoints`, `fn_GetCustomerTier`) + 2 Inline Table-Valued Functions (`fn_GetBooksByGenre`, `fn_GetLowStockBooks`). |
| 07 | `07_views.sql` | **6 Views nghiệp vụ**: `vw_BookCatalog`, `vw_OrderSummary`, `vw_TopSellingBooks`, `vw_MonthlyRevenue`, `vw_CustomerSummary`, `vw_EmployeeInfo`. |
| 08 | `08_procedures.sql` | **6 Stored Procedures nghiệp vụ** (`sp_Login`, `sp_CreateOrder`, `sp_CancelOrder`, `sp_UpdateBookStock`, `sp_SearchBooks`, `sp_GetRevenueReport`) + Hệ thống Stored Procedures CRUD cho các thực thể. |
| 09 | `09_triggers.sql` | **6 Database Triggers**: Tự động trừ tồn kho khi xuất hóa đơn, tích lũy điểm thưởng thành viên, hoàn kho và trừ điểm khi hủy đơn, chặn sửa hóa đơn đã hoàn tất, tự động ghi nhật ký `AuditLog` khi sửa giá sách và cập nhật nhân viên. |
| 10 | `10_transactions.sql` | **5 kịch bản Giao dịch (Transactions)**: Xử lý giao dịch bán hàng, điều chỉnh kho, bảo vệ tính nhất quán dữ liệu có đầy đủ các nhánh `COMMIT TRAN` và `ROLLBACK TRAN`. |
| 11 | `11_security.sql` | **Phân quyền bảo mật (Security)**: Thiết lập 5 Login/User và 5 Database Roles (`role_admin`, `role_manager`, `role_sales`, `role_inventory`, `role_auth`) tuân thủ nguyên tắc đặc quyền tối thiểu (Least Privilege) và phân nhiệm (Separation of Duties). |
| 12 | `12_concurrency_demo.sql` | Kịch bản mô phỏng tranh chấp đồng thời: 2 phiên cùng mua cuốn sách cuối cùng, Deadlock, so sánh mức độ cô lập (Isolation Levels) và quy trình Backup/Restore CSDL. |

---

## 3. CÁC PHÂN HỆ CHỨC NĂNG ỨNG DỤNG

1. **Xác thực & Phân quyền (Authentication & RBAC)**:
   - Đăng nhập bảo mật bằng cơ chế mã hóa mật khẩu PBKDF2-HMAC-SHA256 (100.000 vòng lặp, salt 16 bytes).
   - Điều hướng động thanh Navigation và kiểm tra quyền hạn chặt chẽ theo vai trò (Role).
2. **Bán hàng tại quầy (POS)**:
   - Tìm kiếm sách nhanh, lọc sách còn hàng, thêm vào giỏ hàng, tự động giới hạn số lượng theo tồn kho thực tế.
   - Chọn khách hàng thành viên (hiển thị điểm tích lũy hiện có) hoặc Khách vãng lai.
   - Hỗ trợ phương thức thanh toán Tiền mặt (`Cash`) hoặc Chuyển khoản (`Transfer`).
   - Đóng gói giỏ hàng dạng JSON và gọi Stored Procedure `sp_CreateOrder` trong Transaction; Trigger tự động trừ kho và cộng điểm thưởng.
3. **Quản lý Hóa đơn & Hủy đơn**:
   - Tra cứu, lọc hóa đơn theo mã đơn hàng hoặc trạng thái (`Completed`, `Cancelled`, `Pending`).
   - Xem chi tiết từng hóa đơn, danh sách sách đã mua, thành tiền và điểm thưởng.
   - Hỗ trợ thao tác Hủy hóa đơn (`sp_CancelOrder`): Trigger tự động hoàn trả số lượng sách về kho và khấu trừ lại điểm tích lũy.
4. **Quản lý Danh mục Sách & Kho**:
   - Lọc sách theo từ khóa tựa sách/tác giả, thể loại, khoảng giá và trạng thái tồn kho (`sp_SearchBooks`).
   - Thêm mới, chỉnh sửa thông tin sách, cập nhật số lượng tồn kho.
   - Ghi nhận lịch sử kiểm toán tự động qua Trigger `trg_AuditBookPrice` khi đơn giá sách thay đổi.
5. **Quản lý Thể loại, Tác giả, Nhà xuất bản**:
   - Giao diện quản lý CRUD trực quan thông qua các Stored Procedures tương ứng.
6. **Quản lý Khách hàng & Thành viên**:
   - Tra cứu danh sách khách hàng, số điện thoại, điểm tích lũy.
   - Tự động hiển thị hạng thành viên (Standard, Silver, Gold, VIP) tính toán từ Function `dbo.fn_GetCustomerTier`.
   - Xem chi tiết lịch sử mua hàng của từng khách hàng.
7. **Quản trị Nhân viên**:
   - Dành riêng cho vai trò `Admin`: Thêm tài khoản nhân viên, đổi vai trò, đổi mật khẩu (mã hóa PBKDF2).
   - Trigger `trg_AuditEmployee` tự động ghi nhận các thay đổi vai trò hoặc tài khoản vào `AuditLog`.
8. **Báo cáo & Thống kê**:
   - **Báo cáo doanh thu**: Lọc theo khoảng thời gian (`sp_GetRevenueReport`) và tổng hợp doanh thu theo tháng (View `vw_MonthlyRevenue`).
   - **Top sách bán chạy**: Xếp hạng các đầu sách có doanh số và doanh thu cao nhất (View `vw_TopSellingBooks`).
   - **Cảnh báo tồn kho thấp**: Tra cứu các đầu sách có lượng tồn &le; ngưỡng quy định (Function `dbo.fn_GetLowStockBooks`).
   - **Nhật ký kiểm toán (Audit Log)**: Xem lịch sử các thay đổi nhạy cảm (giá sách, nhân viên), thời gian thực hiện và dữ liệu trước/sau thay đổi.

---

## 4. HƯỚNG DẪN CÀI ĐẶT & KHỞI CHẠY

### Bước 1: Khởi tạo Cơ Sở Dữ Liệu
Sử dụng công cụ **SQL Server Management Studio (SSMS)** hoặc công cụ quản trị CSDL tương đương, kết nối tới SQL Server instance và thực thi tuần tự các tệp kịch bản trong thư mục `database/`:
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
Tạo tệp `.env` tại thư mục gốc dự án (sao chép từ `.env.example`):
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

### Bước 3: Cài đặt Thư viện & Khởi động Web Server
1. Khởi động terminal hoặc PowerShell tại thư mục gốc dự án:
```powershell
# Kích hoạt môi trường ảo
.\venv\Scripts\Activate.ps1

# Cài đặt các thư viện phụ thuộc
pip install -r requirements.txt
```

2. Khởi chạy máy chủ Web FastAPI qua Uvicorn:
```powershell
uvicorn app.main:app --reload --port 8000
```

3. Truy cập hệ thống qua trình duyệt web tại địa chỉ:
```text
http://127.0.0.1:8000
```

---

## 5. TÀI KHOẢN MẶC ĐỊNH & PHÂN QUYỀN TRUY CẬP (RBAC)

| Tên Đăng Nhập | Mật Khẩu | Vai Trò (Role) | Phạm Vi Quyền Hạn |
|:---|:---|:---:|:---|
| `admin` | `admin123` | **Admin** | Quản trị kỹ thuật hệ thống, quản lý nhân viên, cấu hình phân quyền và giám sát AuditLog (Tuân thủ nguyên tắc Separation of Duties, không tham gia giao dịch bán hàng POS). |
| `manager` | `manager123` | **Manager** | Giám sát vận hành bán hàng, quản lý danh mục sách, đối tác, khách hàng và xem toàn bộ báo cáo doanh thu. |
| `sales` | `sales123` | **Sales** | Bán hàng tại quầy (POS), lập và tra cứu lịch sử hóa đơn, quản lý thông tin khách hàng. |
| `inventory` | `inventory123` | **Inventory** | Quản lý kho hàng, điều chỉnh số lượng tồn, quản lý danh mục tác giả, thể loại, NXB. |

---

## 6. KIỂM TRA TRẠNG THÁI HỆ THỐNG (SYSTEM VERIFICATION)

Kiểm tra khả năng nạp mô-đun ứng dụng và tính tương thích của hệ thống:
```powershell
python -c "from app.main import app; print('He thong san sang hoat dong.')"
```