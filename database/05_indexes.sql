USE BookStore;
GO

-- 1. Index on Book(Title) for title search queries
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Book_Title' AND object_id = OBJECT_ID(N'dbo.Book'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Book_Title ON dbo.Book (Title);
END
GO

-- 2. Covering index for time-range revenue reporting
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Orders_OrderDate' AND object_id = OBJECT_ID(N'dbo.Orders'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Orders_OrderDate ON dbo.Orders (OrderDate) INCLUDE (Status);
END
GO

-- 3. Foreign key index on Orders(CustomerID) for customer purchase history
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Orders_CustomerID' AND object_id = OBJECT_ID(N'dbo.Orders'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Orders_CustomerID ON dbo.Orders (CustomerID);
END
GO

-- 4. Covering index for top-selling books aggregation
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OrderDetails_BookID' AND object_id = OBJECT_ID(N'dbo.OrderDetails'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_OrderDetails_BookID ON dbo.OrderDetails (BookID) INCLUDE (Quantity, UnitPrice);
END
GO

-- 5. Composite covering index for genre filtering
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Book_GenreID' AND object_id = OBJECT_ID(N'dbo.Book'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Book_GenreID ON dbo.Book (GenreID) INCLUDE (Title, Price, StockQuantity);
END
GO

-- 6. Foreign key index on Book(AuthorID) for author filtering
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Book_AuthorID' AND object_id = OBJECT_ID(N'dbo.Book'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Book_AuthorID ON dbo.Book (AuthorID);
END
GO

-- Benchmark demonstration section for performance verification
SET STATISTICS IO, TIME ON;
GO

-- Query 1: Prefix search on Book Title (demonstrates Index Seek)
SELECT BookID, Title, Price, StockQuantity
FROM dbo.Book
WHERE Title LIKE N'Harry Potter%';
GO

-- Query 2: Sales report aggregation by BookID (demonstrates Index Scan on covering index)
SELECT 
    BookID,
    SUM(Quantity) AS TotalQuantity,
    SUM(Quantity * UnitPrice) AS TotalRevenue
FROM dbo.OrderDetails
GROUP BY BookID;
GO

SET STATISTICS IO, TIME OFF;
GO
