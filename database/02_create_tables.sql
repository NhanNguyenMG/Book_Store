USE BookStore;
GO

IF OBJECT_ID(N'dbo.Genres', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Genres (
        GenreID INT IDENTITY(1,1) NOT NULL,
        GenreName NVARCHAR(50) NOT NULL,
        CONSTRAINT PK_Genres PRIMARY KEY CLUSTERED (GenreID)
    );
END
GO

IF OBJECT_ID(N'dbo.Author', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Author (
        AuthorID INT IDENTITY(1,1) NOT NULL,
        AuthorName NVARCHAR(100) NOT NULL,
        Yob INT NULL,
        Nationality NVARCHAR(50) NULL,
        CONSTRAINT PK_Author PRIMARY KEY CLUSTERED (AuthorID)
    );
END
GO

IF OBJECT_ID(N'dbo.Publisher', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Publisher (
        PublisherID INT IDENTITY(1,1) NOT NULL,
        PublisherName NVARCHAR(100) NOT NULL,
        Address NVARCHAR(200) NULL,
        Phone VARCHAR(15) NULL,
        CONSTRAINT PK_Publisher PRIMARY KEY CLUSTERED (PublisherID)
    );
END
GO

IF OBJECT_ID(N'dbo.Employee', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Employee (
        EmployeeID INT IDENTITY(1,1) NOT NULL,
        FullName NVARCHAR(100) NOT NULL,
        Role VARCHAR(20) NOT NULL,
        Username VARCHAR(50) NOT NULL,
        Password VARCHAR(255) NOT NULL,
        CONSTRAINT PK_Employee PRIMARY KEY CLUSTERED (EmployeeID)
    );
END
GO

IF OBJECT_ID(N'dbo.Customer', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Customer (
        CustomerID INT IDENTITY(1,1) NOT NULL,
        CustomerName NVARCHAR(100) NOT NULL,
        Phone VARCHAR(15) NOT NULL,
        RewardPoints INT NOT NULL,
        CONSTRAINT PK_Customer PRIMARY KEY CLUSTERED (CustomerID)
    );
END
GO

IF OBJECT_ID(N'dbo.Book', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Book (
        BookID INT IDENTITY(1,1) NOT NULL,
        Title NVARCHAR(200) NOT NULL,
        GenreID INT NOT NULL,
        AuthorID INT NOT NULL,
        PublisherID INT NOT NULL,
        Price MONEY NOT NULL,
        StockQuantity INT NOT NULL,
        CONSTRAINT PK_Book PRIMARY KEY CLUSTERED (BookID),
        CONSTRAINT FK_Book_Genres FOREIGN KEY (GenreID) REFERENCES dbo.Genres(GenreID),
        CONSTRAINT FK_Book_Author FOREIGN KEY (AuthorID) REFERENCES dbo.Author(AuthorID),
        CONSTRAINT FK_Book_Publisher FOREIGN KEY (PublisherID) REFERENCES dbo.Publisher(PublisherID)
    );
END
GO

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Orders (
        OrderID INT IDENTITY(1,1) NOT NULL,
        CustomerID INT NULL,
        EmployeeID INT NOT NULL,
        OrderDate DATETIME NOT NULL,
        Status VARCHAR(20) NOT NULL,
        PaymentMethod VARCHAR(20) NOT NULL,
        CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID),
        CONSTRAINT FK_Orders_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customer(CustomerID),
        CONSTRAINT FK_Orders_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.Employee(EmployeeID)
    );
END
GO

IF OBJECT_ID(N'dbo.OrderDetails', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OrderDetails (
        OrderID INT NOT NULL,
        BookID INT NOT NULL,
        Quantity INT NOT NULL,
        UnitPrice MONEY NOT NULL,
        CONSTRAINT PK_OrderDetails PRIMARY KEY CLUSTERED (OrderID, BookID),
        CONSTRAINT FK_OrderDetails_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID),
        CONSTRAINT FK_OrderDetails_Book FOREIGN KEY (BookID) REFERENCES dbo.Book(BookID)
    );
END
GO

-- AuditLog has no FKs to preserve log entries even if referenced entities are modified or removed
IF OBJECT_ID(N'dbo.AuditLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLog (
        LogID INT IDENTITY(1,1) NOT NULL,
        TableName VARCHAR(50) NOT NULL,
        ActionType VARCHAR(10) NOT NULL,
        RecordID VARCHAR(50) NOT NULL,
        ChangedBy VARCHAR(100) NULL,
        ChangedDate DATETIME NOT NULL,
        OldData NVARCHAR(MAX) NULL,
        NewData NVARCHAR(MAX) NULL,
        CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (LogID)
    );
END
GO
