# HỆ THỐNG QUẢN LÝ NHÀ SÁCH (BOOK STORE MANAGEMENT SYSTEM)

Hệ thống quản lý vận hành nội bộ và bán hàng tại quầy (Back-Office & POS) cho chuỗi nhà sách, xây dựng theo kiến trúc **Fat-Database (Logic-in-DB)** kết hợp cơ chế kiểm soát truy cập dựa trên vai trò đa tầng (**Multi-Layer RBAC**).

---

## 1. TỔNG QUAN HỆ THỐNG

Hệ thống được thiết kế theo mô hình kiến trúc phân tầng tập trung xử lý tại cơ sở dữ liệu:
- **Cơ sở dữ liệu (Microsoft SQL Server)**: Đóng vai trò hạt nhân trung tâm, chịu trách nhiệm lưu trữ và thực thi toàn bộ quy tắc nghiệp vụ (Business Rules), tính toàn vẹn dữ liệu (Constraints), kiểm soát đồng thời & giao dịch (Transactions/ACID), phân quyền bảo mật trực tiếp theo vai trò (Database Roles & Logins), tự động kích hoạt tính toán và ghi nhật ký kiểm toán bất biến (Audit Logging qua Triggers).
- **Ứng dụng Web (FastAPI + Jinja2 + Bootstrap 5 + pyodbc)**: Giao diện trực quan phục vụ vận hành. Ứng dụng không sử dụng ORM (thực thi truy vấn tham số hóa trực tiếp 100% qua `pyodbc`), đồng bộ hóa các route handler với AnyIO Worker ThreadPool, tiếp nhận tương tác người dùng, gọi trực tiếp các Stored Procedures / Views / Functions và kết xuất giao diện HTML Server-Side Rendering (SSR).

---

## 2. TECH STACK & MÔI TRƯỜNG THỰC THI

### 2.1. Backend & Thư viện (Python)
Theo quy chuẩn trong [`requirements.txt`](requirements.txt):
- **Ngôn ngữ**: Python 3.10+ (Đã kiểm thử thực tế trên môi trường Python 3.14)
- **Web Framework**: `fastapi==0.142.2`
- **ASGI Web Server**: `uvicorn==0.54.0`
- **Database Driver**: `pyodbc==5.3.0` (Kết nối SQL Server qua ODBC Driver 17/18, truy vấn tham số hóa 100%)
- **Template Engine**: `Jinja2==3.1.6` (Server-Side Rendering)
- **Mã hóa Mật khẩu**: `bcrypt==5.0.0` (Thuật toán Blowfish-based hashing, 12 rounds salt ngẫu nhiên, kiểm soát chặt chẽ độ dài tối đa 72 bytes)
- **Quản lý Session**: `itsdangerous==2.2.0` (Ký số mật mã cho Session Cookie)
- **Xử lý Dữ liệu Form & Request**: `python-multipart==0.0.32`, `pydantic==2.13.5`
- **Cấu hình Môi trường**: `python-dotenv==1.2.4`
- **HTTP Client / Testing**: `httpx==0.28.1`

### 2.2. Cơ sở dữ liệu (Database)
- **Hệ quản trị CSDL**: Microsoft SQL Server (2019 / 2022 / SQL Server Express)
- **Driver kết nối**: ODBC Driver 17 for SQL Server hoặc ODBC Driver 18 for SQL Server
- **Collation**: `Vietnamese_CI_AS` (Hỗ trợ tìm kiếm tiếng Việt không phân biệt hoa/thường)

### 2.3. Giao diện (Frontend)
Theo quy chuẩn trong [`app/templates/base.html`](app/templates/base.html):
- **CSS Framework**: Bootstrap `5.3.3` (CDN)
- **Biểu tượng (Icon Set)**: Bootstrap Icons `1.11.3` (CDN)
- **Kiến trúc giao diện**: Server-Side Rendering (SSR) thuần túy, Responsive layout, hiển thị báo cáo & chỉ số bằng KPI Cards và Bảng dữ liệu chuẩn (không phụ thuộc thư viện đồ thị client-side).

---

## 3. KIẾN TRÚC CƠ SỞ DỮ LIỆU & QUY TRÌNH NẠP KỊCH BẢN SQL

Toàn bộ kịch bản SQL được lưu trữ tại thư mục `database/` gồm 12 tệp theo quy chuẩn thứ tự thực thi:

| STT | Tệp SQL | Trạng Thái | Nội Dung & Tiêu Chí Kỹ Thuật |
|:---:|:---|:---:|:---|
| 01 | `01_create_database.sql` | **Bắt buộc** | Khởi tạo CSDL `BookStore` với collation chuẩn tiếng Việt `Vietnamese_CI_AS`. |
| 02 | `02_create_tables.sql` | **Bắt buộc** | Thiết kế 9 bảng chuẩn 3NF: `Genres`, `Author`, `Publisher`, `Employee`, `Customer`, `Book`, `Orders`, `OrderDetails`, `AuditLog`. |
| 03 | `03_sample_data.sql` | **Bắt buộc** | Nạp dữ liệu mẫu thực tế: 6 thể loại, 19 tác giả, 5 NXB, 4 nhân viên (mật khẩu mã hóa chuẩn bcrypt), 8 khách hàng, 35 đầu sách, 16 hóa đơn mẫu. |
| 04 | `04_constraints.sql` | **Bắt buộc** | **21 ràng buộc toàn vẹn**: 11 `CHECK` (giá > 0, tồn >= 0, số lượng bán > 0, đơn giá >= 0, điểm thưởng >= 0, định dạng SĐT, năm sinh tác giả, vai trò nhân viên, trạng thái đơn, phương thức thanh toán, loại hành động audit), 4 `UNIQUE` (tên thể loại, SĐT NXB, username nhân viên, SĐT khách hàng), 6 `DEFAULT`. |
| 05 | `05_indexes.sql` | **Bắt buộc** | **6 chỉ mục Non-Clustered (`IX_`)** tối ưu hiệu năng tìm kiếm sách, lọc đơn hàng và tổng hợp báo cáo. |
| 06 | `06_functions.sql` | **Bắt buộc** | **5 UDFs**: 3 Scalar Functions (`fn_GetOrderTotal`, `fn_CalculateRewardPoints`, `fn_GetCustomerTier`) + 2 Inline Table-Valued Functions (`fn_GetBooksByGenre`, `fn_GetLowStockBooks`). |
| 07 | `07_views.sql` | **Bắt buộc** | **6 Views nghiệp vụ**: `vw_BookCatalog`, `vw_OrderSummary`, `vw_TopSellingBooks`, `vw_MonthlyRevenue`, `vw_CustomerSummary`, `vw_EmployeeInfo`. |
| 08 | `08_procedures.sql` | **Bắt buộc** | **33 Stored Procedures**: Gồm 6 SP nghiệp vụ lõi (`sp_Login`, `sp_CreateOrder`, `sp_CancelOrder`, `sp_UpdateBookStock`, `sp_SearchBooks`, `sp_GetRevenueReport`) và 27 SP CRUD cho các bảng thực thể. Tồn kho và điểm thưởng được bảo vệ: `sp_Book_Insert` mặc định kho = 0, `sp_Book_Update` không nhận tham số tồn kho (mọi biến động tồn kho đi qua `sp_UpdateBookStock`); `sp_Customer_Insert` mặc định điểm thưởng = 0 (điểm chỉ được tích lũy tự động qua Trigger khi hoàn tất đơn hàng). |
| 09 | `09_triggers.sql` | **Bắt buộc** | **6 Database Triggers**: Tự động trừ tồn kho khi bán hàng, cộng điểm thưởng khi đơn hoàn tất, hoàn kho và khấu trừ điểm khi hủy đơn, chặn sửa chi tiết đơn hàng đã chốt, ghi nhật ký kiểm toán `trg_Book_Audit` (INSERT/UPDATE/DELETE, đổi giá, đổi tồn kho thủ công) và `trg_Employee_Audit` (nhân viên, đổi role, đổi mật khẩu). |
| 10 | `10_transactions.sql` | *Minh họa (Không bắt buộc)* | **5 kịch bản Giao dịch (Transactions)**: Xử lý giao dịch bán hàng, hủy đơn, phục hồi trạng thái (`COMMIT` / `ROLLBACK`). *(Lưu ý: File này thực thi các đơn hàng và thao tác thay đổi dữ liệu mẫu; chỉ chạy khi cần demo kiểm thử tính nguyên tử/nhất quán).* |
| 11 | `11_security.sql` | **Bắt buộc** | **Phân quyền bảo mật (Security)**: Thiết lập 5 Login/User và 5 Database Roles (`role_admin`, `role_manager`, `role_sales`, `role_inventory`, `role_auth`) tuân thủ nghiêm ngặt nguyên tắc đặc quyền tối thiểu (Least Privilege) và phân nhiệm (Separation of Duties). Cấm DML trực tiếp đối với các vai trò nghiệp vụ (Manager, Sales, Inventory), khóa quyền sửa/xóa `AuditLog`. |
| 12 | `12_concurrency_demo.sql` | *Minh họa (Không bắt buộc)* | **Kịch bản kiểm thử Tranh chấp đồng thời**: Mô phỏng 2 phiên cùng mua cuốn sách cuối cùng, Deadlock, so sánh các mức cô lập (Isolation Levels). *(Lưu ý: File này chứa lệnh giảm tồn kho về 1 và giữ khóa giao dịch; chỉ chạy trong các phiên SSMS riêng biệt để demo).* |

---

## 4. MA TRẬN PHÂN QUYỀN TRUY CẬP (RBAC MATRIX)

Hệ thống áp dụng mô hình **Phòng thủ đa lớp (Defense in Depth)**:
1. **Lớp Ứng dụng (Web Guard)**: Sử dụng FastAPI Dependency `require_role([...])` kiểm tra quyền hạn ngay tại route và ẩn/hiện menu điều hướng trên giao diện.
2. **Lớp Cơ sở dữ liệu (Database Security)**: Mỗi vai trò ứng dụng tương ứng với 1 Database User và Role riêng biệt (`role_admin`, `role_manager`, `role_sales`, `role_inventory`, `role_auth`). Dữ liệu được đóng gói thông qua Stored Procedures; các thao tác INSERT/UPDATE/DELETE trực tiếp trên các bảng nghiệp vụ bị thu hồi (`REVOKE`) hoặc cấm (`DENY`).

| Phân hệ / Chức năng | URL Route (FastAPI) | Route Guard (`require_role`) | Đối tượng SQL Server (`11_security.sql`) | Admin | Manager | Sales | Inventory |
|---|---|---|---|:---:|:---:|:---:|:---:|
| **Đăng nhập hệ thống** | `/login` | Public | `sp_Login` (Cấp riêng qua `role_auth`) | ✔ | ✔ | ✔ | ✔ |
| **Bán hàng tại quầy (POS)** | `/orders/create` | `Sales`, `Manager` | `sp_CreateOrder` (Admin bị `DENY`) | ❌ | ✔ | ✔ | ❌ |
| **Lịch sử hóa đơn** | `/orders`, `/orders/{id}` | `Admin`, `Manager`, `Sales` | `Orders`, `OrderDetails`, `vw_OrderSummary` | ✔ *(Xem)* | ✔ | ✔ | ❌ |
| **Hủy hóa đơn** | `/orders/{id}/cancel` | `Manager`, `Sales` | `sp_CancelOrder` (Admin bị `DENY`) | ❌ | ✔ | ✔ | ❌ |
| **Tra cứu danh mục sách** | `/books` | Mọi user đăng nhập | `sp_SearchBooks`, `vw_BookCatalog` | ✔ | ✔ | ✔ | ✔ |
| **Thêm sách mới** | `/books/create` | `Manager` | `sp_Book_Insert` (Admin bị `DENY`, tồn kho = 0) | ❌ | ✔ | ❌ | ❌ |
| **Sửa thông tin sách** | `/books/{id}/edit` | `Manager` | `sp_Book_Update` (Admin bị `DENY`, không đổi tồn kho) | ❌ | ✔ | ❌ | ❌ |
| **Xóa sách** | `/books/{id}/delete` | `Manager` | `sp_Book_Delete` (Admin bị `DENY`) | ❌ | ✔ | ❌ | ❌ |
| **Nhập/Xuất kho (Đổi tồn)** | `/books/{id}/stock` | `Inventory` | `sp_UpdateBookStock` (Admin, Manager bị `DENY`) | ❌ | ❌ | ❌ | ✔ |
| **Xem Thể loại / Tác giả / NXB** | `/genres`, `/authors`, `/publishers` | `Admin`, `Manager`, `Inventory` | `sp_*_GetAll`, `Genres`, `Author`, `Publisher` | ✔ *(Xem)* | ✔ | ❌ *(Chỉ xem khi bán)* | ✔ *(Xem)* |
| **Thêm / Sửa / Xóa Danh mục** | `/genres/*`, `/authors/*`, `/publishers/*` | `Manager` | `sp_*_Insert/Update/Delete` (Admin bị `DENY`) | ❌ | ✔ | ❌ | ❌ |
| **Xem danh sách Khách hàng** | `/customers`, `/customers/{id}` | `Admin`, `Manager`, `Sales` | `Customer`, `sp_Customer_GetAll/GetById` | ✔ *(Xem)* | ✔ | ✔ | ❌ |
| **Thêm / Sửa Khách hàng** | `/customers/create`, `/edit` | `Manager`, `Sales` | `sp_Customer_Insert/Update` (Admin bị `DENY`, tạo mới mặc định điểm = 0) | ❌ | ✔ | ✔ | ❌ |
| **Xóa Khách hàng** | `/customers/{id}/delete` | `Manager` | `sp_Customer_Delete` (Admin bị `DENY`, Sales chưa được cấp quyền) | ❌ | ✔ | ❌ | ❌ |
| **Quản trị Nhân viên** | `/employees/**` | `Admin` | `sp_Employee_*`, `Employee` (Role khác bị `DENY`) | ✔ | ❌ | ❌ | ❌ |
| **Báo cáo Doanh thu** | `/reports/revenue` | `Admin`, `Manager` | `sp_GetRevenueReport`, `vw_MonthlyRevenue` | ✔ | ✔ | ❌ | ❌ |
| **Top Sách Bán Chạy** | `/reports/top-selling` | `Admin`, `Manager` | `vw_TopSellingBooks` | ✔ | ✔ | ❌ | ❌ |
| **Cảnh báo Tồn kho thấp** | `/reports/low-stock` | `Admin`, `Manager`, `Inventory` | `fn_GetLowStockBooks` | ✔ | ✔ | ❌ | ✔ |
| **Nhật ký Kiểm toán (AuditLog)** | `/reports/audit-logs` | `Admin` | `AuditLog` (Role khác bị `DENY`, Toàn quyền chỉ đọc) | ✔ *(Chỉ đọc)* | ❌ | ❌ | ❌ |

> [!NOTE]
> **Nguyên tắc Phân nhiệm (Separation of Duties - SoD)**:
> - **Admin** chỉ tập trung quản trị tài khoản nhân viên, cấu hình kỹ thuật và giám sát AuditLog; không tham gia quy trình bán hàng POS (không tạo đơn hay hủy đơn), không nhập kho, không sửa đổi danh mục nghiệp vụ hay khách hàng (chỉ có quyền xem tra cứu).
> - **Manager** quản lý danh mục và đối tác nhưng **tuyệt đối không được can thiệp vào tồn kho**; không được quản trị nhân viên hay xem nhật ký hệ thống.
> - **Inventory (Thủ kho)** chịu trách nhiệm duy nhất về số lượng tồn kho (thông qua `sp_UpdateBookStock`), chỉ xem danh mục sách/đối tác mà không có quyền thêm/sửa/xóa danh mục.
> - **Sales** chỉ thao tác bán hàng, xuất/hủy đơn và chăm sóc khách hàng; không truy cập các báo cáo quản trị cấp cao.

---

## 5. CƠ CHẾ BẢO MẬT & NHẬT KÝ KIỂM TOÁN (AUDIT LOG)

### 5.1. Cơ chế Mã hóa Mật khẩu (bcrypt)
- Ứng dụng sử dụng thư viện `bcrypt==5.0.0` với cấu hình muối ngẫu nhiên 12 vòng lặp (`bcrypt.gensalt(rounds=12)`).
- Chuỗi mã hóa sinh ra có định dạng `$2b$12$...` (chiều dài 60 ký tự, lưu trữ an toàn trong cột `Password VARCHAR(255)`).
- **Kiểm soát độ dài**: Thuật toán bcrypt giới hạn xử lý tối đa 72 bytes. Hệ thống kiểm tra chặt chẽ độ dài chuỗi UTF-8 tại cả giao diện người dùng (`maxlength="72"`) và tầng xử lý backend trước khi gọi hàm băm nhằm tránh việc mật khẩu bị cắt ngắn hoặc báo lỗi.
- Hàm kiểm tra mật khẩu từ chối tất cả các định dạng không hợp chuẩn bcrypt hoặc chuỗi rỗng.

### 5.2. Quản lý Phiên làm việc (Session Management)
- Phiên làm việc được quản lý thông qua `SessionMiddleware` của Starlette với chữ ký số mật mã (`itsdangerous`).
- **Thời hạn phiên (`SESSION_MAX_AGE`)**: Được cấu hình qua biến môi trường với giá trị mặc định là **`28800` giây (8 tiếng)**, tương ứng thời gian một ca làm việc tiêu chuẩn của nhân viên bán lẻ, ngăn chặn việc phiên tồn tại vô thời hạn sau khi tắt trình duyệt.

### 5.3. Cơ chế Truyền ngữ cảnh phiên xuống Database (`SESSION_CONTEXT`)
Khi ứng dụng gửi yêu cầu xuống SQL Server, hàm `execute_sp` trong [`app/database.py`](app/database.py) tự động thực thi:
```sql
EXEC sys.sp_set_session_context @key = N'EmployeeID', @value = ?;
```
Nhờ cơ chế này, các Database Trigger trong SQL Server luôn xác định được chính xác danh tính nhân viên đang thực hiện thao tác trên web, giải quyết bài toán mất dấu vết người dùng khi kết nối qua Connection Pool.

### 5.4. Quy tắc Ghi nhận Nhật ký Kiểm toán (AuditLog)
Trigger `trg_Book_Audit` và `trg_Employee_Audit` tự động giám sát các thay đổi nhạy cảm:
- **Bảng Sách (`Book`)**:
  - Ghi nhận `INSERT`: Lưu thông tin tựa sách, giá bán và số lượng tồn ban đầu.
  - Ghi nhận `UPDATE (Price)`: Lưu biến động giá cũ (`OldData`) và giá mới (`NewData`).
  - Ghi nhận `UPDATE (StockQuantity)`: **Chỉ ghi nhận khi tồn kho được điều chỉnh thủ công** bởi Thủ kho qua `sp_UpdateBookStock` hoặc thao tác trực tiếp. Nhờ điều kiện `TRIGGER_NESTLEVEL() <= 1`, các biến động tồn kho tự động phát sinh từ việc xuất hóa đơn (`trg_OrderDetails_AfterInsert`) hoặc hủy hóa đơn (`trg_Orders_OnCancel`) sẽ **không bị ghi trùng lặp**, giữ cho nhật ký kiểm toán không bị nhiễu.
  - Ghi nhận `DELETE`: Lưu thông tin bản ghi sách bị xóa.
- **Bảng Nhân viên (`Employee`)**:
  - Ghi nhận `INSERT`: Lưu Username, Họ tên, Role (tuyệt đối không ghi chuỗi hash mật khẩu vào log).
  - Ghi nhận `UPDATE`: Ghi nhận thay đổi chức vụ, họ tên, và gắn nhãn `[Đã đổi mật khẩu]` nếu mật khẩu bị thay đổi.
  - Ghi nhận `DELETE`: Lưu thông tin tài khoản nhân viên bị xóa khỏi hệ thống.
- **Cột `ChangedBy`**:
  - Thao tác qua Web: Hiển thị định dạng chuẩn `username (ID n)` (ví dụ: `admin (ID 1)`, `inventory (ID 4)`).
  - Thao tác trực tiếp ngoài ứng dụng (T-SQL / SSMS): Hiển thị `[Ngoài ứng dụng] <SQL_LOGIN>`.
- **Tính Bất Biến (Immutability)**:
  - Lệnh `DENY UPDATE, DELETE ON dbo.AuditLog` được áp dụng cho toàn bộ 5 Database Roles. Không một tài khoản nào (kể cả Admin trong phiên làm việc thông thường) có thể chỉnh sửa hoặc xóa dữ liệu nhật ký kiểm toán đã ghi nhận.

---

## 6. HƯỚNG DẪN CÀI ĐẶT & KHỞI CHẠY

### Bước 1: Khởi tạo Cơ Sở Dữ Liệu
Sử dụng công cụ **SQL Server Management Studio (SSMS)** kết nối tới SQL Server instance và thực thi tuần tự các tệp kịch bản bắt buộc từ `01` đến `11` (bỏ qua tệp `10` và `12` nếu không muốn làm sai lệch dữ liệu mẫu):

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
database/11_security.sql
```

> [!WARNING]
> Tệp `10_transactions.sql` và `12_concurrency_demo.sql` là các kịch bản kiểm thử mẫu. Chỉ chạy các tệp này khi cần demo tranh chấp khóa, kiểm thử rollback giao dịch, hoặc kiểm tra mức độ cô lập.

### Bước 2: Cấu hình Môi trường Ứng dụng
Tạo tệp `.env` tại thư mục gốc dự án dựa trên mẫu [`.env.example`](.env.example):
```ini
# Cấu hình kết nối Cơ sở dữ liệu
DB_SERVER=.\SQLEXPRESS
DB_NAME=BookStore
DB_DRIVER=ODBC Driver 18 for SQL Server
DB_TRUST_SERVER_CERT=yes

# Chế độ xác thực: WINDOWS_AUTH hoặc SQL_LOGIN
# Khuyến nghị dùng SQL_LOGIN khi demo thực tế cơ chế phân quyền Database Roles
DB_AUTH_MODE=WINDOWS_AUTH

# Tài khoản SQL Server tương ứng từng vai trò (Sử dụng khi DB_AUTH_MODE=SQL_LOGIN)
DB_USER_ADMIN=login_admin
DB_PASS_ADMIN=BookStore@Admin123

DB_USER_MANAGER=login_manager
DB_PASS_MANAGER=BookStore@Manager123

DB_USER_SALES=login_sales
DB_PASS_SALES=BookStore@Sales123

DB_USER_INVENTORY=login_inventory
DB_PASS_INVENTORY=BookStore@Inventory123

DB_USER_AUTH=login_auth
DB_PASS_AUTH=BookStore@Auth123

# Bảo mật Phiên làm việc (Session Cookie)
SESSION_SECRET_KEY=bookstore-super-secret-key-2026-secure-session
SESSION_MAX_AGE=28800
```

### Bước 3: Cài đặt Môi trường & Khởi động Web Server
1. Mở terminal hoặc PowerShell tại thư mục gốc dự án:
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

3. Mở trình duyệt web và truy cập hệ thống tại:
```text
http://127.0.0.1:8000
```

---

## 7. TÀI KHOẢN MẶC ĐỊNH & THỬ NGHIỆM

Hệ thống đi kèm 4 tài khoản nhân viên mặc định phục vụ kiểm thử 4 phân hệ quyền hạn:

| Username | Password | Vai Trò (Role) | Mô Tả Phạm Vi Quyền Hạn |
|:---|:---|:---:|:---|
| `admin` | `admin123` | **Admin** | Quản trị kỹ thuật, quản lý tài khoản nhân viên, cấu hình phân quyền và giám sát `AuditLog`. Không tham gia bán hàng POS (không tạo hay hủy đơn), không sửa tồn kho hay thêm/sửa/xóa danh mục sách/khách hàng (chỉ có quyền tra cứu/xem). |
| `manager` | `manager123` | **Manager** | Quản lý danh mục sách, thể loại, tác giả, nhà xuất bản, khách hàng; xem toàn bộ báo cáo doanh thu; có thể lập và hủy hóa đơn. Tuyệt đối không được sửa đổi tồn kho trực tiếp. |
| `sales` | `sales123` | **Sales** | Bán hàng tại quầy (POS), lập và hủy hóa đơn, tra cứu sách còn hàng, thêm mới và quản lý thông tin khách hàng thành viên. |
| `inventory` | `inventory123` | **Inventory** | Thủ kho: Tra cứu danh mục, theo dõi cảnh báo tồn kho thấp, thực hiện nhập kho/xuất kho (điều chỉnh tăng/giảm tồn kho qua `sp_UpdateBookStock`). Không sửa thông tin sách hay giá bán. |

---

## 8. KIỂM TRA TRẠNG THÁI HỆ THỐNG (SYSTEM VERIFICATION)

Chạy lệnh kiểm tra tính tương thích và khả năng nạp mô-đun ứng dụng:
```powershell
python -c "from app.main import app; print('He thong BookStore san sang hoat dong.')"
```