USE BookStore;
GO

-- 1. Authentication procedure returning user profile and hashed password
CREATE OR ALTER PROCEDURE dbo.sp_Login
    @Username VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 
        EmployeeID,
        FullName,
        Role,
        Username,
        Password
    FROM dbo.Employee
    WHERE Username = @Username;
END;
GO

-- 2. Transactional order creation parsing JSON payload and querying DB book prices
CREATE OR ALTER PROCEDURE dbo.sp_CreateOrder
    @EmployeeID INT,
    @CustomerID INT = NULL,
    @PaymentMethod VARCHAR(20) = 'Cash',
    @CartJson NVARCHAR(MAX),
    @NewOrderID INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISJSON(@CartJson) <> 1
    BEGIN
        THROW 50001, N'Dữ liệu giỏ hàng định dạng JSON không hợp lệ.', 1;
    END

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, Status, PaymentMethod)
        VALUES (@CustomerID, @EmployeeID, GETDATE(), 'Pending', @PaymentMethod);

        SET @NewOrderID = SCOPE_IDENTITY();

        -- Insert details querying authoritative unit prices directly from Book table
        INSERT INTO dbo.OrderDetails (OrderID, BookID, Quantity, UnitPrice)
        SELECT 
            @NewOrderID,
            c.BookID,
            c.Quantity,
            b.Price
        FROM OPENJSON(@CartJson)
        WITH (
            BookID INT '$.BookID',
            Quantity INT '$.Quantity'
        ) c
        INNER JOIN dbo.Book b ON c.BookID = b.BookID;

        -- Transition status to Completed to trigger stock deduction and loyalty points
        UPDATE dbo.Orders
        SET Status = 'Completed'
        WHERE OrderID = @NewOrderID;

        COMMIT TRAN;

        SELECT @NewOrderID AS OrderID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        IF ERROR_NUMBER() = 547
            THROW 50002, N'Không đủ số lượng tồn kho cho một hoặc nhiều sách trong đơn hàng.', 1;
        ELSE
            THROW;
    END CATCH;
END;
GO

-- 3. Cancel order procedure triggering inventory restoration and points rollback
CREATE OR ALTER PROCEDURE dbo.sp_CancelOrder
    @OrderID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM dbo.Orders WHERE OrderID = @OrderID)
        BEGIN
            THROW 50003, N'Không tìm thấy hóa đơn cần hủy.', 1;
        END

        IF EXISTS (SELECT 1 FROM dbo.Orders WHERE OrderID = @OrderID AND Status = 'Cancelled')
        BEGIN
            THROW 50004, N'Hóa đơn này đã được hủy trước đó.', 1;
        END

        UPDATE dbo.Orders
        SET Status = 'Cancelled'
        WHERE OrderID = @OrderID;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

-- 4. Adjust book stock level
CREATE OR ALTER PROCEDURE dbo.sp_UpdateBookStock
    @BookID INT,
    @Delta INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM dbo.Book WHERE BookID = @BookID)
        BEGIN
            THROW 50005, N'Không tìm thấy sách với mã chỉ định.', 1;
        END

        UPDATE dbo.Book
        SET StockQuantity = StockQuantity + @Delta
        WHERE BookID = @BookID;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        IF ERROR_NUMBER() = 547
            THROW 50006, N'Số lượng tồn kho sau cập nhật không được phép âm.', 1;
        ELSE
            THROW;
    END CATCH;
END;
GO

-- 5. Multi-criteria book search
CREATE OR ALTER PROCEDURE dbo.sp_SearchBooks
    @Keyword NVARCHAR(100) = NULL,
    @GenreID INT = NULL,
    @AuthorID INT = NULL,
    @MinPrice MONEY = NULL,
    @MaxPrice MONEY = NULL,
    @InStockOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        b.BookID,
        b.Title,
        g.GenreID,
        g.GenreName,
        a.AuthorID,
        a.AuthorName,
        p.PublisherID,
        p.PublisherName,
        b.Price,
        b.StockQuantity
    FROM dbo.Book b
    INNER JOIN dbo.Genres g ON b.GenreID = g.GenreID
    INNER JOIN dbo.Author a ON b.AuthorID = a.AuthorID
    INNER JOIN dbo.Publisher p ON b.PublisherID = p.PublisherID
    WHERE (@Keyword IS NULL OR b.Title LIKE N'%' + @Keyword + N'%' OR a.AuthorName LIKE N'%' + @Keyword + N'%')
      AND (@GenreID IS NULL OR b.GenreID = @GenreID)
      AND (@AuthorID IS NULL OR b.AuthorID = @AuthorID)
      AND (@MinPrice IS NULL OR b.Price >= @MinPrice)
      AND (@MaxPrice IS NULL OR b.Price <= @MaxPrice)
      AND (@InStockOnly = 0 OR b.StockQuantity > 0)
    ORDER BY b.Title ASC;
END;
GO

-- 6. Revenue summary report by date range
CREATE OR ALTER PROCEDURE dbo.sp_GetRevenueReport
    @FromDate DATETIME,
    @ToDate DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        ISNULL(SUM(od.Quantity), 0) AS TotalBooksSold,
        ISNULL(SUM(od.Quantity * od.UnitPrice), 0) AS TotalRevenue
    FROM dbo.Orders o
    INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
    WHERE o.Status = 'Completed'
      AND o.OrderDate >= @FromDate
      AND o.OrderDate <= @ToDate;
END;
GO

-- CRUD Procedures: Genres
CREATE OR ALTER PROCEDURE dbo.sp_Genres_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT GenreID, GenreName FROM dbo.Genres ORDER BY GenreName ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Genres_Insert
    @GenreName NVARCHAR(50),
    @NewID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO dbo.Genres (GenreName) VALUES (@GenreName);
        SET @NewID = SCOPE_IDENTITY();
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Genres_Update
    @GenreID INT,
    @GenreName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.Genres SET GenreName = @GenreName WHERE GenreID = @GenreID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Genres_Delete
    @GenreID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM dbo.Genres WHERE GenreID = @GenreID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

-- CRUD Procedures: Author
CREATE OR ALTER PROCEDURE dbo.sp_Author_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT AuthorID, AuthorName, Yob, Nationality FROM dbo.Author ORDER BY AuthorName ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Author_Insert
    @AuthorName NVARCHAR(100),
    @Yob INT = NULL,
    @Nationality NVARCHAR(50) = NULL,
    @NewID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO dbo.Author (AuthorName, Yob, Nationality) VALUES (@AuthorName, @Yob, @Nationality);
        SET @NewID = SCOPE_IDENTITY();
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Author_Update
    @AuthorID INT,
    @AuthorName NVARCHAR(100),
    @Yob INT = NULL,
    @Nationality NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.Author
        SET AuthorName = @AuthorName, Yob = @Yob, Nationality = @Nationality
        WHERE AuthorID = @AuthorID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Author_Delete
    @AuthorID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM dbo.Author WHERE AuthorID = @AuthorID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

-- CRUD Procedures: Publisher
CREATE OR ALTER PROCEDURE dbo.sp_Publisher_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PublisherID, PublisherName, Address, Phone FROM dbo.Publisher ORDER BY PublisherName ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Publisher_Insert
    @PublisherName NVARCHAR(100),
    @Address NVARCHAR(200) = NULL,
    @Phone VARCHAR(15) = NULL,
    @NewID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO dbo.Publisher (PublisherName, Address, Phone) VALUES (@PublisherName, @Address, @Phone);
        SET @NewID = SCOPE_IDENTITY();
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Publisher_Update
    @PublisherID INT,
    @PublisherName NVARCHAR(100),
    @Address NVARCHAR(200) = NULL,
    @Phone VARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.Publisher
        SET PublisherName = @PublisherName, Address = @Address, Phone = @Phone
        WHERE PublisherID = @PublisherID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Publisher_Delete
    @PublisherID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM dbo.Publisher WHERE PublisherID = @PublisherID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

-- CRUD Procedures: Book
CREATE OR ALTER PROCEDURE dbo.sp_Book_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_BookCatalog ORDER BY Title ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Book_GetById
    @BookID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_BookCatalog WHERE BookID = @BookID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Book_Insert
    @Title NVARCHAR(200),
    @GenreID INT,
    @AuthorID INT,
    @PublisherID INT,
    @Price MONEY,
    @StockQuantity INT = 0,
    @NewID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO dbo.Book (Title, GenreID, AuthorID, PublisherID, Price, StockQuantity)
        VALUES (@Title, @GenreID, @AuthorID, @PublisherID, @Price, @StockQuantity);
        SET @NewID = SCOPE_IDENTITY();
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Book_Update
    @BookID INT,
    @Title NVARCHAR(200),
    @GenreID INT,
    @AuthorID INT,
    @PublisherID INT,
    @Price MONEY,
    @StockQuantity INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.Book
        SET Title = @Title,
            GenreID = @GenreID,
            AuthorID = @AuthorID,
            PublisherID = @PublisherID,
            Price = @Price,
            StockQuantity = @StockQuantity
        WHERE BookID = @BookID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Book_Delete
    @BookID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM dbo.Book WHERE BookID = @BookID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

-- CRUD Procedures: Customer
CREATE OR ALTER PROCEDURE dbo.sp_Customer_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CustomerID, CustomerName, Phone, RewardPoints, dbo.fn_GetCustomerTier(CustomerID) AS Tier
    FROM dbo.Customer
    ORDER BY CustomerName ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Customer_GetById
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CustomerID, CustomerName, Phone, RewardPoints, dbo.fn_GetCustomerTier(CustomerID) AS Tier
    FROM dbo.Customer
    WHERE CustomerID = @CustomerID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Customer_Insert
    @CustomerName NVARCHAR(100),
    @Phone VARCHAR(15),
    @RewardPoints INT = 0,
    @NewID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO dbo.Customer (CustomerName, Phone, RewardPoints)
        VALUES (@CustomerName, @Phone, @RewardPoints);
        SET @NewID = SCOPE_IDENTITY();
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Customer_Update
    @CustomerID INT,
    @CustomerName NVARCHAR(100),
    @Phone VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.Customer
        SET CustomerName = @CustomerName, Phone = @Phone
        WHERE CustomerID = @CustomerID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Customer_Delete
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM dbo.Customer WHERE CustomerID = @CustomerID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

-- CRUD Procedures: Employee
CREATE OR ALTER PROCEDURE dbo.sp_Employee_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_EmployeeInfo ORDER BY FullName ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_GetById
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_EmployeeInfo WHERE EmployeeID = @EmployeeID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_Insert
    @FullName NVARCHAR(100),
    @Role VARCHAR(20),
    @Username VARCHAR(50),
    @Password VARCHAR(255),
    @NewID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO dbo.Employee (FullName, Role, Username, Password)
        VALUES (@FullName, @Role, @Username, @Password);
        SET @NewID = SCOPE_IDENTITY();
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_Update
    @EmployeeID INT,
    @FullName NVARCHAR(100),
    @Role VARCHAR(20),
    @Password VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        IF @Password IS NOT NULL AND LEN(@Password) > 0
        BEGIN
            UPDATE dbo.Employee
            SET FullName = @FullName, Role = @Role, Password = @Password
            WHERE EmployeeID = @EmployeeID;
        END
        ELSE
        BEGIN
            UPDATE dbo.Employee
            SET FullName = @FullName, Role = @Role
            WHERE EmployeeID = @EmployeeID;
        END
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Employee_Delete
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM dbo.Employee WHERE EmployeeID = @EmployeeID;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO
