USE BookStore;
GO

-- 1. Calculate total monetary value of an order
CREATE OR ALTER FUNCTION dbo.fn_GetOrderTotal (@OrderID INT)
RETURNS MONEY
AS
BEGIN
    DECLARE @Total MONEY;
    SELECT @Total = ISNULL(SUM(Quantity * UnitPrice), 0)
    FROM dbo.OrderDetails
    WHERE OrderID = @OrderID;
    RETURN @Total;
END;
GO

-- 2. Calculate reward points based on total amount (100,000 VND = 1 point)
CREATE OR ALTER FUNCTION dbo.fn_CalculateRewardPoints (@Total MONEY)
RETURNS INT
AS
BEGIN
    IF @Total IS NULL OR @Total < 100000
        RETURN 0;
    RETURN CAST(FLOOR(@Total / 100000) AS INT);
END;
GO

-- 3. Determine customer loyalty tier based on accumulated reward points
CREATE OR ALTER FUNCTION dbo.fn_GetCustomerTier (@CustomerID INT)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @Points INT;
    SELECT @Points = RewardPoints
    FROM dbo.Customer
    WHERE CustomerID = @CustomerID;

    IF @Points IS NULL
        RETURN N'Standard';
    IF @Points >= 50
        RETURN N'VIP';
    IF @Points >= 20
        RETURN N'Gold';
    IF @Points >= 10
        RETURN N'Silver';
    RETURN N'Standard';
END;
GO

-- 4. Inline table-valued function: Books filtered by genre with author and publisher names
CREATE OR ALTER FUNCTION dbo.fn_GetBooksByGenre (@GenreID INT)
RETURNS TABLE
AS
RETURN (
    SELECT 
        b.BookID,
        b.Title,
        a.AuthorName,
        p.PublisherName,
        b.Price,
        b.StockQuantity
    FROM dbo.Book b
    INNER JOIN dbo.Author a ON b.AuthorID = a.AuthorID
    INNER JOIN dbo.Publisher p ON b.PublisherID = p.PublisherID
    WHERE b.GenreID = @GenreID
);
GO

-- 5. Inline table-valued function: Books with stock level at or below threshold
CREATE OR ALTER FUNCTION dbo.fn_GetLowStockBooks (@Threshold INT)
RETURNS TABLE
AS
RETURN (
    SELECT 
        b.BookID,
        b.Title,
        g.GenreName,
        b.StockQuantity,
        b.Price
    FROM dbo.Book b
    INNER JOIN dbo.Genres g ON b.GenreID = g.GenreID
    WHERE b.StockQuantity <= @Threshold
);
GO
