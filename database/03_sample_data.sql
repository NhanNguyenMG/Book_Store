USE BookStore;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Genres)
BEGIN
    SET IDENTITY_INSERT dbo.Genres ON;
    INSERT INTO dbo.Genres (GenreID, GenreName) VALUES
        (1, N'Văn học'),
        (2, N'Khoa học - Công nghệ'),
        (3, N'Kinh tế - Kỹ năng'),
        (4, N'Lịch sử - Xã hội'),
        (5, N'Tâm lý - Đời sống'),
        (6, N'Thiếu nhi - Truyện tranh');
    SET IDENTITY_INSERT dbo.Genres OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Author)
BEGIN
    SET IDENTITY_INSERT dbo.Author ON;
    INSERT INTO dbo.Author (AuthorID, AuthorName, Yob, Nationality) VALUES
        (1, N'Nguyễn Nhật Ánh', 1955, N'Việt Nam'),
        (2, N'Nam Cao', 1915, N'Việt Nam'),
        (3, N'Vũ Trọng Phụng', 1912, N'Việt Nam'),
        (4, N'Dale Carnegie', 1888, N'Mỹ'),
        (5, N'Robert Kiyosaki', 1947, N'Mỹ'),
        (6, N'Haruki Murakami', 1949, N'Nhật Bản'),
        (7, N'Yuval Noah Harari', 1976, N'Israel'),
        (8, N'J.K. Rowling', 1965, N'Anh'),
        (9, N'Stephen Hawking', 1942, N'Anh'),
        (10, N'Walter Isaacson', 1952, N'Mỹ'),
        (11, N'Phil Knight', 1938, N'Mỹ'),
        (12, N'Paulo Coelho', 1947, N'Brazil'),
        (13, N'Daniel Kahneman', 1934, N'Israel'),
        (14, N'Steven Levitt', 1967, N'Mỹ'),
        (15, N'Eric Ries', 1978, N'Mỹ'),
        (16, N'Baird T. Spalding', 1872, N'Mỹ'),
        (17, N'J.D. Salinger', 1919, N'Mỹ'),
        (18, N'Rosie Nguyễn', 1987, N'Việt Nam'),
        (19, N'Tô Hoài', 1920, N'Việt Nam');
    SET IDENTITY_INSERT dbo.Author OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Publisher)
BEGIN
    SET IDENTITY_INSERT dbo.Publisher ON;
    INSERT INTO dbo.Publisher (PublisherID, PublisherName, Address, Phone) VALUES
        (1, N'NXB Trẻ', N'161B Lý Chính Thắng, Quận 3, TP.HCM', '02839316289'),
        (2, N'NXB Kim Đồng', N'55 Quang Trung, Hai Bà Trưng, Hà Nội', '02439434730'),
        (3, N'NXB Tổng Hợp TP.HCM', N'62 Nguyễn Thị Minh Khai, Quận 1, TP.HCM', '02838225340'),
        (4, N'NXB Phụ Nữ', N'39 Hàng Chuối, Hai Bà Trưng, Hà Nội', '02439710798'),
        (5, N'NXB Thế Giới', N'46 Trần Hưng Đạo, Hoàn Kiếm, Hà Nội', '02438253841');
    SET IDENTITY_INSERT dbo.Publisher OFF;
END
GO

-- Employee passwords hashed with pbkdf2_hmac sha256 (format: salt$hash)
IF NOT EXISTS (SELECT 1 FROM dbo.Employee)
BEGIN
    SET IDENTITY_INSERT dbo.Employee ON;
    INSERT INTO dbo.Employee (EmployeeID, FullName, Role, Username, Password) VALUES
        (1, N'Nguyễn Văn Quản Trị', 'Admin', 'admin', '7bb000f8c2d6e2e665d9a845d3b505bf$9c0734e0f6df5ef3ede8074fa4777187e03112f3f88c940ed26e289f6bae58bd'),
        (2, N'Trần Thị Quản Lý', 'Manager', 'manager', 'e3266bdcf0335436d7c77be71e2dffc2$17bb85e7ad6f14003212868feb0501a53d5751fff4503af114571bfee3d7654a'),
        (3, N'Lê Văn Bán Hàng', 'Sales', 'sales', 'a346de60cea1ad76eeff43985765e0f6$1ebc34c10e5a5c895dcd769d01306f6ca157a4524866da75006a787cabb60d4d'),
        (4, N'Phạm Văn Thủ Kho', 'Inventory', 'inventory', 'a139d542224bb0f3f6496c9775ff99f4$bc706004a05497ce413c887e33b5c82d4c7bc306efec8ebca63bac8e8b33448f');
    SET IDENTITY_INSERT dbo.Employee OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Customer)
BEGIN
    SET IDENTITY_INSERT dbo.Customer ON;
    INSERT INTO dbo.Customer (CustomerID, CustomerName, Phone, RewardPoints) VALUES
        (1, N'Trần Tuấn Anh', '0901234567', 7),
        (2, N'Lê Phương Linh', '0912345678', 7),
        (3, N'Phạm Hoàng Long', '0983456789', 12),
        (4, N'Vũ Minh Trang', '0974567890', 3),
        (5, N'Đặng Thùy Dương', '0935678901', 0),
        (6, N'Hoàng Đức Minh', '0946789012', 11),
        (7, N'Bùi Thu Hà', '0967890123', 3),
        (8, N'Ngô Quốc Bảo', '0928901234', 9);
    SET IDENTITY_INSERT dbo.Customer OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Book)
BEGIN
    SET IDENTITY_INSERT dbo.Book ON;
    INSERT INTO dbo.Book (BookID, Title, GenreID, AuthorID, PublisherID, Price, StockQuantity) VALUES
        (1, N'Mắt Biếc', 1, 1, 1, 110000, 45),
        (2, N'Tôi Thấy Hoa Vàng Trên Cỏ Xanh', 1, 1, 1, 125000, 50),
        (3, N'Cho Tôi Xin Một Vé Đi Tuổi Thơ', 1, 1, 1, 95000, 30),
        (4, N'Cô Gái Đến Từ Hôm Qua', 1, 1, 1, 85000, 20),
        (5, N'Chí Phèo', 1, 2, 3, 65000, 35),
        (6, N'Lão Hạc', 1, 2, 3, 60000, 25),
        (7, N'Số Đỏ', 1, 3, 3, 85000, 40),
        (8, N'Giông Tố', 1, 3, 3, 90000, 15),
        (9, N'Rừng Na Uy', 1, 6, 4, 140000, 28),
        (10, N'Kafka Bên Bờ Biển', 1, 6, 4, 160000, 18),
        (11, N'Harry Potter và Hòn Đá Phù Thủy', 6, 8, 1, 185000, 60),
        (12, N'Harry Potter và Phòng Chứa Bí Mật', 6, 8, 1, 195000, 55),
        (13, N'Harry Potter và Tên Tù Nhân Ngục Azkaban', 6, 8, 1, 210000, 40),
        (14, N'Lược Sử Thời Gian', 2, 9, 5, 135000, 32),
        (15, N'Vũ Trụ Trong Vỏ Hạt Dẻ', 2, 9, 5, 150000, 4),
        (16, N'Lược Sử Loài Người (Sapiens)', 4, 7, 5, 220000, 70),
        (17, N'Lược Sử Tương Lai (Homo Deus)', 4, 7, 5, 230000, 50),
        (18, N'21 Bài Học Cho Thế Kỷ 21', 4, 7, 5, 210000, 35),
        (19, N'Steve Jobs', 2, 10, 5, 280000, 22),
        (20, N'Einstein: Cuộc Đời Và Vũ Trụ', 2, 10, 5, 260000, 16),
        (21, N'Elon Musk', 2, 10, 5, 290000, 3),
        (22, N'Đắc Nhân Tâm', 5, 4, 5, 86000, 120),
        (23, N'Quẳng Gánh Lo Đi Và Vui Sống', 5, 4, 5, 92000, 85),
        (24, N'Dạy Con Làm Giàu - Tập 1', 3, 5, 1, 80000, 95),
        (25, N'Dạy Con Làm Giàu - Tập 2', 3, 5, 1, 85000, 75),
        (26, N'Dạy Con Làm Giàu - Tập 3', 3, 5, 1, 90000, 60),
        (27, N'Dốc Mộng Lớn (Shoe Dog)', 3, 11, 3, 175000, 30),
        (28, N'Nhà Giả Kim', 5, 12, 4, 79000, 110),
        (29, N'Tư Duy Nhanh Và Chậm', 5, 13, 5, 240000, 40),
        (30, N'Kinh Tế Học Hài Hước', 3, 14, 3, 130000, 25),
        (31, N'Khởi Nghiệp Tinh Gọn', 3, 15, 5, 145000, 38),
        (32, N'Hành Trình Về Phương Đông', 4, 16, 5, 105000, 50),
        (33, N'Bắt Trẻ Đồng Xanh', 1, 17, 4, 98000, 35),
        (34, N'Tuổi Trẻ Đáng Giá Bao Nhiêu', 5, 18, 4, 85000, 90),
        (35, N'Dế Mèn Phiêu Lưu Ký', 6, 19, 2, 55000, 100);
    SET IDENTITY_INSERT dbo.Book OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Orders)
BEGIN
    SET IDENTITY_INSERT dbo.Orders ON;
    INSERT INTO dbo.Orders (OrderID, CustomerID, EmployeeID, OrderDate, Status, PaymentMethod) VALUES
        (1, 1, 3, '20260815 09:30:00', 'Completed', 'Cash'),
        (2, 2, 3, '20260820 14:15:00', 'Completed', 'Transfer'),
        (3, 3, 3, '20260828 10:45:00', 'Completed', 'Cash'),
        (4, 4, 3, '20260902 11:20:00', 'Completed', 'Transfer'),
        (5, 6, 3, '20260905 16:10:00', 'Completed', 'Cash'),
        (6, 7, 3, '20260910 15:30:00', 'Completed', 'Cash'),
        (7, 8, 3, '20260915 08:50:00', 'Completed', 'Transfer'),
        (8, NULL, 3, '20260918 13:40:00', 'Completed', 'Cash'),
        (9, 1, 3, '20260922 17:05:00', 'Completed', 'Transfer'),
        (10, 2, 3, '20260925 10:15:00', 'Completed', 'Cash'),
        (11, 3, 3, '20260928 18:25:00', 'Completed', 'Transfer'),
        (12, 6, 3, '20261001 09:10:00', 'Completed', 'Cash'),
        (13, 8, 3, '20261002 11:00:00', 'Completed', 'Transfer'),
        (14, NULL, 3, '20261002 14:45:00', 'Completed', 'Cash'),
        (15, 5, 3, '20261003 08:30:00', 'Pending', 'Cash'),
        (16, 4, 3, '20261003 09:00:00', 'Cancelled', 'Transfer');
    SET IDENTITY_INSERT dbo.Orders OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.OrderDetails)
BEGIN
    INSERT INTO dbo.OrderDetails (OrderID, BookID, Quantity, UnitPrice) VALUES
        (1, 1, 2, 110000),
        (1, 22, 1, 86000),
        (2, 16, 1, 220000),
        (2, 17, 1, 230000),
        (3, 11, 2, 185000),
        (3, 12, 1, 195000),
        (3, 13, 1, 210000),
        (4, 24, 2, 80000),
        (4, 25, 2, 85000),
        (5, 14, 1, 135000),
        (5, 19, 1, 280000),
        (5, 20, 1, 260000),
        (6, 28, 2, 79000),
        (6, 34, 2, 85000),
        (7, 2, 2, 125000),
        (7, 3, 2, 95000),
        (7, 22, 2, 86000),
        (8, 5, 1, 65000),
        (8, 7, 1, 85000),
        (9, 16, 1, 220000),
        (9, 29, 1, 240000),
        (10, 9, 1, 140000),
        (10, 10, 1, 160000),
        (11, 19, 1, 280000),
        (11, 21, 1, 290000),
        (12, 1, 1, 110000),
        (12, 16, 1, 220000),
        (12, 27, 1, 175000),
        (13, 11, 1, 185000),
        (13, 18, 1, 210000),
        (14, 35, 2, 55000),
        (15, 4, 1, 85000),
        (16, 15, 1, 150000);
END
GO
