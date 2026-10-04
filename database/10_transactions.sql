USE BookStore;
GO

-- ============================================================================
-- Scenario 1: Atomic Sales Order Processing (Demonstrates Atomicity)
-- ============================================================================

-- 1.1. Success Case (COMMIT): Order creation with valid inventory
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID IN (1, 2);
SELECT CustomerID, RewardPoints FROM dbo.Customer WHERE CustomerID = 1;

DECLARE @CartSuccess NVARCHAR(MAX) = N'[{"BookID": 1, "Quantity": 2}, {"BookID": 2, "Quantity": 1}]';
DECLARE @NewID INT;

EXEC dbo.sp_CreateOrder 
    @EmployeeID = 3, 
    @CustomerID = 1, 
    @PaymentMethod = 'Cash', 
    @CartJson = @CartSuccess, 
    @NewOrderID = @NewID OUTPUT;

-- Verify inventory deducted and reward points accumulated
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID IN (1, 2);
SELECT CustomerID, RewardPoints FROM dbo.Customer WHERE CustomerID = 1;
GO

-- 1.2. Failure Case (ROLLBACK): Quantity exceeds available stock
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID = 15;

DECLARE @CartFail NVARCHAR(MAX) = N'[{"BookID": 15, "Quantity": 9999}]';
BEGIN TRY
    EXEC dbo.sp_CreateOrder 
        @EmployeeID = 3, 
        @CustomerID = 1, 
        @PaymentMethod = 'Cash', 
        @CartJson = @CartFail;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- Verify stock unchanged after rollback
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID = 15;
GO


-- ============================================================================
-- Scenario 2: Order Cancellation & State Reversal (Demonstrates Consistency)
-- ============================================================================

-- 2.1. Success Case (COMMIT): Cancelling a completed order restores stock and points
SELECT OrderID, Status FROM dbo.Orders WHERE OrderID = 1;
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID IN (1, 22);
SELECT CustomerID, RewardPoints FROM dbo.Customer WHERE CustomerID = 1;

EXEC dbo.sp_CancelOrder @OrderID = 1;

-- Verify order cancelled, stock restocked, and points revoked
SELECT OrderID, Status FROM dbo.Orders WHERE OrderID = 1;
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID IN (1, 22);
SELECT CustomerID, RewardPoints FROM dbo.Customer WHERE CustomerID = 1;
GO

-- 2.2. Failure Case (ROLLBACK): Attempting to cancel already cancelled order
BEGIN TRY
    EXEC dbo.sp_CancelOrder @OrderID = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
GO


-- ============================================================================
-- Scenario 3: Batch Inventory Restocking (Demonstrates All-or-Nothing Atomicity)
-- ============================================================================

-- 3.1. Success Case (COMMIT): Restocking multiple book titles
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID IN (5, 6);

BEGIN TRANSACTION;
BEGIN TRY
    UPDATE dbo.Book SET StockQuantity = StockQuantity + 20 WHERE BookID = 5;
    UPDATE dbo.Book SET StockQuantity = StockQuantity + 15 WHERE BookID = 6;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID IN (5, 6);
GO

-- 3.2. Failure Case (ROLLBACK): One book fails validation, entire batch reverts
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID IN (7, 8);

BEGIN TRANSACTION;
BEGIN TRY
    UPDATE dbo.Book SET StockQuantity = StockQuantity + 10 WHERE BookID = 7;
    -- Violates CK_Book_Stock (negative stock)
    UPDATE dbo.Book SET StockQuantity = StockQuantity - 9999 WHERE BookID = 8;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- Verify Book 7 was not modified due to transaction rollback
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID IN (7, 8);
GO


-- ============================================================================
-- Scenario 4: Loyalty Reward Points Transfer (Demonstrates Consistency)
-- ============================================================================

-- 4.1. Success Case (COMMIT): Transfer 3 points from Customer 3 to Customer 2
SELECT CustomerID, CustomerName, RewardPoints FROM dbo.Customer WHERE CustomerID IN (2, 3);

BEGIN TRANSACTION;
BEGIN TRY
    UPDATE dbo.Customer SET RewardPoints = RewardPoints - 3 WHERE CustomerID = 3;
    UPDATE dbo.Customer SET RewardPoints = RewardPoints + 3 WHERE CustomerID = 2;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT CustomerID, CustomerName, RewardPoints FROM dbo.Customer WHERE CustomerID IN (2, 3);
GO

-- 4.2. Failure Case (ROLLBACK): Insufficient points causes CK_Customer_Points violation
SELECT CustomerID, CustomerName, RewardPoints FROM dbo.Customer WHERE CustomerID IN (4, 5);

BEGIN TRANSACTION;
BEGIN TRY
    -- Customer 4 currently has 3 points; transferring 50 will trigger constraint violation
    UPDATE dbo.Customer SET RewardPoints = RewardPoints - 50 WHERE CustomerID = 4;
    UPDATE dbo.Customer SET RewardPoints = RewardPoints + 50 WHERE CustomerID = 5;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- Verify both customer balances remain unchanged
SELECT CustomerID, CustomerName, RewardPoints FROM dbo.Customer WHERE CustomerID IN (4, 5);
GO


-- ============================================================================
-- Scenario 5: Merge Duplicate Customer Accounts (Demonstrates Relational Integrity)
-- ============================================================================

-- 5.1. Success Case (COMMIT): Merge Customer 8 into Customer 7
SELECT CustomerID, CustomerName, RewardPoints FROM dbo.Customer WHERE CustomerID IN (7, 8);
SELECT OrderID, CustomerID FROM dbo.Orders WHERE CustomerID = 8;

BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @PointsToTransfer INT;
    SELECT @PointsToTransfer = RewardPoints FROM dbo.Customer WHERE CustomerID = 8;

    -- Reassign orders from Customer 8 to Customer 7
    UPDATE dbo.Orders SET CustomerID = 7 WHERE CustomerID = 8;

    -- Transfer reward points
    UPDATE dbo.Customer SET RewardPoints = RewardPoints + @PointsToTransfer WHERE CustomerID = 7;

    -- Remove merged customer
    DELETE FROM dbo.Customer WHERE CustomerID = 8;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- Verify orders reassigned and Customer 8 removed
SELECT CustomerID, CustomerName, RewardPoints FROM dbo.Customer WHERE CustomerID = 7;
SELECT COUNT(*) AS DeletedCustomerCount FROM dbo.Customer WHERE CustomerID = 8;
SELECT OrderID, CustomerID FROM dbo.Orders WHERE CustomerID = 7;
GO
