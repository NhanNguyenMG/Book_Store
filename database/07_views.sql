USE BookStore;
GO

-- 1. Complete catalog view with genre, author, and publisher descriptions
CREATE OR ALTER VIEW dbo.vw_BookCatalog
AS
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
INNER JOIN dbo.Publisher p ON b.PublisherID = p.PublisherID;
GO

-- 2. Comprehensive order summary with computed total amount
CREATE OR ALTER VIEW dbo.vw_OrderSummary
AS
SELECT 
    o.OrderID,
    o.OrderDate,
    o.CustomerID,
    ISNULL(c.CustomerName, N'Khách vãng lai') AS CustomerName,
    ISNULL(c.Phone, N'') AS CustomerPhone,
    e.EmployeeID,
    e.FullName AS EmployeeName,
    o.Status,
    o.PaymentMethod,
    dbo.fn_GetOrderTotal(o.OrderID) AS TotalAmount
FROM dbo.Orders o
LEFT JOIN dbo.Customer c ON o.CustomerID = c.CustomerID
INNER JOIN dbo.Employee e ON o.EmployeeID = e.EmployeeID;
GO

-- 3. Top-selling books ranking based exclusively on completed orders
CREATE OR ALTER VIEW dbo.vw_TopSellingBooks
AS
SELECT 
    b.BookID,
    b.Title,
    g.GenreName,
    SUM(od.Quantity) AS TotalQuantitySold,
    SUM(od.Quantity * od.UnitPrice) AS TotalRevenue
FROM dbo.OrderDetails od
INNER JOIN dbo.Orders o ON od.OrderID = o.OrderID
INNER JOIN dbo.Book b ON od.BookID = b.BookID
INNER JOIN dbo.Genres g ON b.GenreID = g.GenreID
WHERE o.Status = 'Completed'
GROUP BY b.BookID, b.Title, g.GenreName;
GO

-- 4. Monthly revenue report aggregated only from completed orders
CREATE OR ALTER VIEW dbo.vw_MonthlyRevenue
AS
SELECT 
    YEAR(o.OrderDate) AS [Year],
    MONTH(o.OrderDate) AS [Month],
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    SUM(od.Quantity * od.UnitPrice) AS TotalRevenue
FROM dbo.Orders o
INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
WHERE o.Status = 'Completed'
GROUP BY YEAR(o.OrderDate), MONTH(o.OrderDate);
GO

-- 5. Customer purchasing summary and loyalty tier evaluation
CREATE OR ALTER VIEW dbo.vw_CustomerSummary
AS
SELECT 
    c.CustomerID,
    c.CustomerName,
    c.Phone,
    c.RewardPoints,
    dbo.fn_GetCustomerTier(c.CustomerID) AS Tier,
    COUNT(o.OrderID) AS TotalOrders,
    ISNULL(SUM(dbo.fn_GetOrderTotal(o.OrderID)), 0) AS TotalSpent
FROM dbo.Customer c
LEFT JOIN dbo.Orders o ON c.CustomerID = o.CustomerID AND o.Status = 'Completed'
GROUP BY c.CustomerID, c.CustomerName, c.Phone, c.RewardPoints;
GO

-- 6. Safe employee profile view excluding sensitive password hash
CREATE OR ALTER VIEW dbo.vw_EmployeeInfo
AS
SELECT 
    EmployeeID,
    FullName,
    Role,
    Username
FROM dbo.Employee;
GO
