USE BookStore;
GO

-- 1. Deduct book inventory upon order details insertion
CREATE OR ALTER TRIGGER dbo.trg_OrderDetails_AfterInsert
ON dbo.OrderDetails
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE b
    SET b.StockQuantity = b.StockQuantity - i.TotalQty
    FROM dbo.Book b
    INNER JOIN (
        SELECT BookID, SUM(Quantity) AS TotalQty
        FROM inserted
        GROUP BY BookID
    ) i ON b.BookID = i.BookID;
END;
GO

-- 2. Award loyalty points when order transitions to Completed
CREATE OR ALTER TRIGGER dbo.trg_Orders_RewardPoints
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE c
    SET c.RewardPoints = c.RewardPoints + p.PointsToAdd
    FROM dbo.Customer c
    INNER JOIN (
        SELECT 
            i.CustomerID,
            SUM(dbo.fn_CalculateRewardPoints(dbo.fn_GetOrderTotal(i.OrderID))) AS PointsToAdd
        FROM inserted i
        INNER JOIN deleted d ON i.OrderID = d.OrderID
        WHERE i.Status = 'Completed' 
          AND d.Status <> 'Completed'
          AND i.CustomerID IS NOT NULL
        GROUP BY i.CustomerID
    ) p ON c.CustomerID = p.CustomerID;
END;
GO

-- 3. Restore inventory and rollback loyalty points when completed order is cancelled
CREATE OR ALTER TRIGGER dbo.trg_Orders_OnCancel
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 3.1. Restock items back to Book inventory
    UPDATE b
    SET b.StockQuantity = b.StockQuantity + item.RestoredQty
    FROM dbo.Book b
    INNER JOIN (
        SELECT 
            od.BookID,
            SUM(od.Quantity) AS RestoredQty
        FROM dbo.OrderDetails od
        INNER JOIN inserted i ON od.OrderID = i.OrderID
        INNER JOIN deleted d ON i.OrderID = d.OrderID
        WHERE i.Status = 'Cancelled'
          AND d.Status IN ('Completed', 'Pending')
        GROUP BY od.BookID
    ) item ON b.BookID = item.BookID;

    -- 3.2. Deduct rewarded points from customer avoiding negative balance
    UPDATE c
    SET c.RewardPoints = CASE 
        WHEN c.RewardPoints >= pts.PointsToDeduct THEN c.RewardPoints - pts.PointsToDeduct
        ELSE 0 
    END
    FROM dbo.Customer c
    INNER JOIN (
        SELECT 
            i.CustomerID,
            SUM(dbo.fn_CalculateRewardPoints(dbo.fn_GetOrderTotal(i.OrderID))) AS PointsToDeduct
        FROM inserted i
        INNER JOIN deleted d ON i.OrderID = d.OrderID
        WHERE i.Status = 'Cancelled'
          AND d.Status = 'Completed'
          AND i.CustomerID IS NOT NULL
        GROUP BY i.CustomerID
    ) pts ON c.CustomerID = pts.CustomerID;
END;
GO

-- 4. Block modifications or deletions of details for non-pending orders
CREATE OR ALTER TRIGGER dbo.trg_OrderDetails_Protect
ON dbo.OrderDetails
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM dbo.Orders o
        INNER JOIN (
            SELECT OrderID FROM deleted
            UNION
            SELECT OrderID FROM inserted
        ) affected ON o.OrderID = affected.OrderID
        WHERE o.Status <> 'Pending'
    )
    BEGIN
        THROW 50010, N'Không thể chỉnh sửa hoặc xóa chi tiết của hóa đơn đã hoàn tất hoặc đã hủy.', 1;
    END
END;
GO

-- 5. Audit changes to book prices, stock quantities, insertions, and deletions
CREATE OR ALTER TRIGGER dbo.trg_Book_Audit
ON dbo.Book
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmpID INT = TRY_CAST(SESSION_CONTEXT(N'EmployeeID') AS INT);
    DECLARE @User VARCHAR(100);

    IF @EmpID IS NOT NULL
    BEGIN
        SELECT @User = Username + ' (ID ' + CAST(EmployeeID AS VARCHAR(10)) + ')'
        FROM dbo.Employee
        WHERE EmployeeID = @EmpID;

        IF @User IS NULL
            SET @User = 'Nhân viên ID ' + CAST(@EmpID AS VARCHAR(10));
    END
    ELSE
    BEGIN
        SET @User = '[Ngoài ứng dụng] ' + SUSER_SNAME();
    END

    -- 5.1. Log newly inserted books
    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, ChangedBy, ChangedDate, OldData, NewData)
        SELECT 
            'Book',
            'INSERT',
            CAST(i.BookID AS VARCHAR(50)),
            @User,
            GETDATE(),
            NULL,
            N'Title: ' + i.Title + N', Price: ' + CAST(i.Price AS NVARCHAR(50)) + N', Stock: ' + CAST(i.StockQuantity AS NVARCHAR(50))
        FROM inserted i;
    END

    -- 5.2. Log price updates
    IF UPDATE(Price)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, ChangedBy, ChangedDate, OldData, NewData)
        SELECT 
            'Book',
            'UPDATE',
            CAST(i.BookID AS VARCHAR(50)),
            @User,
            GETDATE(),
            N'Price: ' + CAST(d.Price AS NVARCHAR(50)),
            N'Price: ' + CAST(i.Price AS NVARCHAR(50))
        FROM inserted i
        INNER JOIN deleted d ON i.BookID = d.BookID
        WHERE i.Price <> d.Price;
    END

    -- 5.3. Log inventory stock updates
    IF UPDATE(StockQuantity)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, ChangedBy, ChangedDate, OldData, NewData)
        SELECT 
            'Book',
            'UPDATE',
            CAST(i.BookID AS VARCHAR(50)),
            @User,
            GETDATE(),
            N'Stock: ' + CAST(d.StockQuantity AS NVARCHAR(50)),
            N'Stock: ' + CAST(i.StockQuantity AS NVARCHAR(50))
        FROM inserted i
        INNER JOIN deleted d ON i.BookID = d.BookID
        WHERE i.StockQuantity <> d.StockQuantity;
    END

    -- 5.4. Log deleted books
    IF NOT EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, ChangedBy, ChangedDate, OldData, NewData)
        SELECT 
            'Book',
            'DELETE',
            CAST(d.BookID AS VARCHAR(50)),
            @User,
            GETDATE(),
            N'Title: ' + d.Title + N', Price: ' + CAST(d.Price AS NVARCHAR(50)) + N', Stock: ' + CAST(d.StockQuantity AS NVARCHAR(50)),
            NULL
        FROM deleted d;
    END
END;
GO

-- 6. Audit changes to employee insertions, roles, full names, password updates, and deletions
CREATE OR ALTER TRIGGER dbo.trg_Employee_Audit
ON dbo.Employee
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmpID INT = TRY_CAST(SESSION_CONTEXT(N'EmployeeID') AS INT);
    DECLARE @User VARCHAR(100);

    IF @EmpID IS NOT NULL
    BEGIN
        SELECT @User = Username + ' (ID ' + CAST(EmployeeID AS VARCHAR(10)) + ')'
        FROM dbo.Employee
        WHERE EmployeeID = @EmpID;

        IF @User IS NULL
            SET @User = 'Nhân viên ID ' + CAST(@EmpID AS VARCHAR(10));
    END
    ELSE
    BEGIN
        SET @User = '[Ngoài ứng dụng] ' + SUSER_SNAME();
    END

    -- 6.1. Log newly created employees (Excludes password hash for security)
    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, ChangedBy, ChangedDate, OldData, NewData)
        SELECT 
            'Employee',
            'INSERT',
            CAST(i.EmployeeID AS VARCHAR(50)),
            @User,
            GETDATE(),
            NULL,
            N'Username: ' + i.Username + N', Họ tên: ' + i.FullName + N', Role: ' + i.Role
        FROM inserted i;
    END

    -- 6.2. Log employee updates (Role, FullName, Password change flag)
    IF UPDATE(Role) OR UPDATE(Password) OR UPDATE(FullName)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, ChangedBy, ChangedDate, OldData, NewData)
        SELECT 
            'Employee',
            'UPDATE',
            CAST(i.EmployeeID AS VARCHAR(50)),
            @User,
            GETDATE(),
            N'Role: ' + d.Role + N', Họ tên: ' + d.FullName,
            N'Role: ' + i.Role + N', Họ tên: ' + i.FullName
                + CASE WHEN i.Password <> d.Password THEN N', [Đã đổi mật khẩu]' ELSE N'' END
        FROM inserted i
        INNER JOIN deleted d ON i.EmployeeID = d.EmployeeID
        WHERE i.Role <> d.Role 
           OR i.FullName <> d.FullName 
           OR i.Password <> d.Password;
    END

    -- 6.3. Log deleted employees
    IF NOT EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, ChangedBy, ChangedDate, OldData, NewData)
        SELECT 
            'Employee',
            'DELETE',
            CAST(d.EmployeeID AS VARCHAR(50)),
            @User,
            GETDATE(),
            N'Username: ' + d.Username + N', Họ tên: ' + d.FullName + N', Role: ' + d.Role,
            NULL
        FROM deleted d;
    END
END;
GO
