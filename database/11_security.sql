USE master;
GO

-- Create SQL Server Logins if they do not exist
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_admin')
    CREATE LOGIN login_admin WITH PASSWORD = N'BookStore@Admin123', CHECK_POLICY = OFF;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_manager')
    CREATE LOGIN login_manager WITH PASSWORD = N'BookStore@Manager123', CHECK_POLICY = OFF;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_sales')
    CREATE LOGIN login_sales WITH PASSWORD = N'BookStore@Sales123', CHECK_POLICY = OFF;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_inventory')
    CREATE LOGIN login_inventory WITH PASSWORD = N'BookStore@Inventory123', CHECK_POLICY = OFF;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_auth')
    CREATE LOGIN login_auth WITH PASSWORD = N'BookStore@Auth123', CHECK_POLICY = OFF;
GO

USE BookStore;
GO

-- Create Database Users mapped to Server Logins
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_admin')
    CREATE USER user_admin FOR LOGIN login_admin;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_manager')
    CREATE USER user_manager FOR LOGIN login_manager;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_sales')
    CREATE USER user_sales FOR LOGIN login_sales;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_inventory')
    CREATE USER user_inventory FOR LOGIN login_inventory;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_auth')
    CREATE USER user_auth FOR LOGIN login_auth;
GO

-- Create Database Roles
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_admin' AND type = 'R')
    CREATE ROLE role_admin;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_manager' AND type = 'R')
    CREATE ROLE role_manager;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_sales' AND type = 'R')
    CREATE ROLE role_sales;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_inventory' AND type = 'R')
    CREATE ROLE role_inventory;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'role_auth' AND type = 'R')
    CREATE ROLE role_auth;
GO

-- Assign Users to Roles
ALTER ROLE role_admin ADD MEMBER user_admin;
ALTER ROLE role_manager ADD MEMBER user_manager;
ALTER ROLE role_sales ADD MEMBER user_sales;
ALTER ROLE role_inventory ADD MEMBER user_inventory;
ALTER ROLE role_auth ADD MEMBER user_auth;
GO

-- ============================================================================
-- Permissions Configuration (Least Privilege Principle)
-- ============================================================================

-- 1. Immutable Audit Log: No principal may modify or delete audit log entries
DENY UPDATE, DELETE ON dbo.AuditLog TO role_admin, role_manager, role_sales, role_inventory, role_auth;
GO

-- 2. Technical Authentication Role (role_auth): Only allowed to execute sp_Login
GRANT EXECUTE ON dbo.sp_Login TO role_auth;
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO role_auth;
GO

-- 3. Sales Role (role_sales): Cashier and POS operations
GRANT SELECT ON dbo.vw_BookCatalog TO role_sales;
GRANT SELECT ON dbo.Book TO role_sales;
GRANT SELECT ON dbo.Genres TO role_sales;
GRANT SELECT ON dbo.Author TO role_sales;
GRANT SELECT ON dbo.Publisher TO role_sales;

GRANT SELECT, INSERT, UPDATE ON dbo.Customer TO role_sales;
-- Deny sales employees from manually altering customer points (only triggers/SPs may do so)
DENY UPDATE ON dbo.Customer(RewardPoints) TO role_sales;

GRANT SELECT ON dbo.Orders TO role_sales;
GRANT SELECT ON dbo.OrderDetails TO role_sales;

GRANT EXECUTE ON dbo.sp_CreateOrder TO role_sales;
GRANT EXECUTE ON dbo.sp_CancelOrder TO role_sales;
GRANT EXECUTE ON dbo.sp_SearchBooks TO role_sales;
GRANT EXECUTE ON dbo.sp_Customer_GetAll TO role_sales;
GRANT EXECUTE ON dbo.sp_Customer_GetById TO role_sales;
GRANT EXECUTE ON dbo.sp_Customer_Insert TO role_sales;
GRANT EXECUTE ON dbo.sp_Customer_Update TO role_sales;

DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Employee TO role_sales;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_sales;
DENY SELECT ON dbo.vw_OrderSummary TO role_sales;
DENY SELECT ON dbo.vw_TopSellingBooks TO role_sales;
DENY SELECT ON dbo.vw_MonthlyRevenue TO role_sales;
DENY SELECT ON dbo.vw_CustomerSummary TO role_sales;
DENY SELECT ON dbo.vw_EmployeeInfo TO role_sales;
GO

-- 4. Inventory Role (role_inventory): Warehouse staff
GRANT SELECT ON dbo.vw_BookCatalog TO role_inventory;
GRANT SELECT, INSERT, UPDATE ON dbo.Book TO role_inventory;
GRANT SELECT, INSERT, UPDATE ON dbo.Genres TO role_inventory;
GRANT SELECT, INSERT, UPDATE ON dbo.Author TO role_inventory;
GRANT SELECT, INSERT, UPDATE ON dbo.Publisher TO role_inventory;

GRANT EXECUTE ON dbo.sp_UpdateBookStock TO role_inventory;
GRANT EXECUTE ON dbo.sp_SearchBooks TO role_inventory;
GRANT EXECUTE ON dbo.sp_Book_GetAll TO role_inventory;
GRANT EXECUTE ON dbo.sp_Book_GetById TO role_inventory;
GRANT EXECUTE ON dbo.sp_Book_Insert TO role_inventory;
GRANT EXECUTE ON dbo.sp_Book_Update TO role_inventory;
GRANT EXECUTE ON dbo.sp_Genres_GetAll TO role_inventory;
GRANT EXECUTE ON dbo.sp_Author_GetAll TO role_inventory;
GRANT EXECUTE ON dbo.sp_Publisher_GetAll TO role_inventory;

DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Orders TO role_inventory;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.OrderDetails TO role_inventory;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Customer TO role_inventory;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Employee TO role_inventory;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.AuditLog TO role_inventory;
DENY SELECT ON dbo.vw_OrderSummary TO role_inventory;
DENY SELECT ON dbo.vw_TopSellingBooks TO role_inventory;
DENY SELECT ON dbo.vw_MonthlyRevenue TO role_inventory;
DENY SELECT ON dbo.vw_CustomerSummary TO role_inventory;
DENY SELECT ON dbo.vw_EmployeeInfo TO role_inventory;
GO

-- 5. Manager Role (role_manager): Reporting and catalog management
GRANT SELECT ON SCHEMA::dbo TO role_manager;
GRANT EXECUTE ON SCHEMA::dbo TO role_manager;

-- Prevent manager from viewing password hashes directly; must use vw_EmployeeInfo
DENY SELECT ON dbo.Employee(Password) TO role_manager;
GO

-- 6. Administrator Role (role_admin): Full schema control
GRANT CONTROL ON DATABASE::BookStore TO role_admin;
GO


-- ============================================================================
-- Verification Tests Demonstrating Permissions Enforcement
-- ============================================================================

-- Test 1: Verify role_auth can execute sp_Login but cannot query tables
EXECUTE AS USER = 'user_auth';
EXEC dbo.sp_Login @Username = 'admin';
BEGIN TRY
    SELECT TOP 1 * FROM dbo.Book;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
REVERT;
GO

-- Test 2: Verify role_sales is blocked from direct updates to Customer.RewardPoints
EXECUTE AS USER = 'user_sales';
SELECT TOP 1 CustomerID, CustomerName FROM dbo.Customer;
BEGIN TRY
    UPDATE dbo.Customer SET RewardPoints = 999 WHERE CustomerID = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
REVERT;
GO

-- Test 3: Verify role_inventory cannot read Orders table
EXECUTE AS USER = 'user_inventory';
BEGIN TRY
    SELECT TOP 1 * FROM dbo.Orders;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
REVERT;
GO

-- Test 4: Verify role_manager cannot query Password column directly
EXECUTE AS USER = 'user_manager';
SELECT TOP 1 EmployeeID, FullName, Role, Username FROM dbo.vw_EmployeeInfo;
BEGIN TRY
    SELECT TOP 1 Password FROM dbo.Employee;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
REVERT;
GO

-- Test 5: Verify even user_admin cannot delete rows from AuditLog
EXECUTE AS USER = 'user_admin';
BEGIN TRY
    DELETE FROM dbo.AuditLog;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
REVERT;
GO
