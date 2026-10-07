USE BookStore;
GO

IF OBJECT_ID(N'dbo.CK_Book_Price') IS NULL
BEGIN
    ALTER TABLE dbo.Book ADD CONSTRAINT CK_Book_Price CHECK (Price > 0);
END
GO

-- Defense against negative inventory under concurrent transactions
IF OBJECT_ID(N'dbo.CK_Book_Stock') IS NULL
BEGIN
    ALTER TABLE dbo.Book ADD CONSTRAINT CK_Book_Stock CHECK (StockQuantity >= 0);
END
GO

IF OBJECT_ID(N'dbo.CK_Customer_Points') IS NULL
BEGIN
    ALTER TABLE dbo.Customer ADD CONSTRAINT CK_Customer_Points CHECK (RewardPoints >= 0);
END
GO

-- Customer phone must contain only digits with length between 9 and 11
IF OBJECT_ID(N'dbo.CK_Customer_Phone') IS NULL
BEGIN
    ALTER TABLE dbo.Customer ADD CONSTRAINT CK_Customer_Phone CHECK (
        Phone NOT LIKE '%[^0-9]%' AND LEN(Phone) BETWEEN 9 AND 11
    );
END
GO

-- Deterministic birth year range constraint
IF OBJECT_ID(N'dbo.CK_Author_Yob') IS NULL
BEGIN
    ALTER TABLE dbo.Author ADD CONSTRAINT CK_Author_Yob CHECK (
        Yob >= 1800 AND Yob <= 2100
    );
END
GO

IF OBJECT_ID(N'dbo.CK_Employee_Role') IS NULL
BEGIN
    ALTER TABLE dbo.Employee ADD CONSTRAINT CK_Employee_Role CHECK (
        Role IN ('Admin', 'Manager', 'Sales', 'Inventory')
    );
END
GO

IF OBJECT_ID(N'dbo.CK_Orders_Status') IS NULL
BEGIN
    ALTER TABLE dbo.Orders ADD CONSTRAINT CK_Orders_Status CHECK (
        Status IN ('Pending', 'Completed', 'Cancelled')
    );
END
GO

IF OBJECT_ID(N'dbo.CK_Orders_Payment') IS NULL
BEGIN
    ALTER TABLE dbo.Orders ADD CONSTRAINT CK_Orders_Payment CHECK (
        PaymentMethod IN ('Cash', 'Transfer')
    );
END
GO

IF OBJECT_ID(N'dbo.CK_OD_Quantity') IS NULL
BEGIN
    ALTER TABLE dbo.OrderDetails ADD CONSTRAINT CK_OD_Quantity CHECK (Quantity > 0);
END
GO

IF OBJECT_ID(N'dbo.CK_OD_UnitPrice') IS NULL
BEGIN
    ALTER TABLE dbo.OrderDetails ADD CONSTRAINT CK_OD_UnitPrice CHECK (UnitPrice >= 0);
END
GO

IF OBJECT_ID(N'dbo.CK_AuditLog_ActionType') IS NULL
BEGIN
    ALTER TABLE dbo.AuditLog ADD CONSTRAINT CK_AuditLog_ActionType CHECK (
        ActionType IN ('INSERT', 'UPDATE', 'DELETE')
    );
END
GO

IF OBJECT_ID(N'dbo.UQ_Genres_Name') IS NULL
BEGIN
    ALTER TABLE dbo.Genres ADD CONSTRAINT UQ_Genres_Name UNIQUE (GenreName);
END
GO

IF OBJECT_ID(N'dbo.UQ_Publisher_Phone') IS NULL
BEGIN
    ALTER TABLE dbo.Publisher ADD CONSTRAINT UQ_Publisher_Phone UNIQUE (Phone);
END
GO

IF OBJECT_ID(N'dbo.UQ_Employee_Username') IS NULL
BEGIN
    ALTER TABLE dbo.Employee ADD CONSTRAINT UQ_Employee_Username UNIQUE (Username);
END
GO

IF OBJECT_ID(N'dbo.UQ_Customer_Phone') IS NULL
BEGIN
    ALTER TABLE dbo.Customer ADD CONSTRAINT UQ_Customer_Phone UNIQUE (Phone);
END
GO

IF OBJECT_ID(N'dbo.DF_Book_Stock') IS NULL
BEGIN
    ALTER TABLE dbo.Book ADD CONSTRAINT DF_Book_Stock DEFAULT 0 FOR StockQuantity;
END
GO

IF OBJECT_ID(N'dbo.DF_Customer_Points') IS NULL
BEGIN
    ALTER TABLE dbo.Customer ADD CONSTRAINT DF_Customer_Points DEFAULT 0 FOR RewardPoints;
END
GO

IF OBJECT_ID(N'dbo.DF_Orders_Date') IS NULL
BEGIN
    ALTER TABLE dbo.Orders ADD CONSTRAINT DF_Orders_Date DEFAULT GETDATE() FOR OrderDate;
END
GO

IF OBJECT_ID(N'dbo.DF_Orders_Status') IS NULL
BEGIN
    ALTER TABLE dbo.Orders ADD CONSTRAINT DF_Orders_Status DEFAULT 'Pending' FOR Status;
END
GO

IF OBJECT_ID(N'dbo.DF_Orders_Payment') IS NULL
BEGIN
    ALTER TABLE dbo.Orders ADD CONSTRAINT DF_Orders_Payment DEFAULT 'Cash' FOR PaymentMethod;
END
GO

IF OBJECT_ID(N'dbo.DF_AuditLog_Date') IS NULL
BEGIN
    ALTER TABLE dbo.AuditLog ADD CONSTRAINT DF_AuditLog_Date DEFAULT GETDATE() FOR ChangedDate;
END
GO
