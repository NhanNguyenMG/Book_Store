USE BookStore;
GO

-- ============================================================================
-- Section 1: Race Condition on Last Inventory Item (Two Concurrent Buyers)
-- Run Session 1 and Session 2 in separate SSMS query windows simultaneously.
-- ============================================================================

-- Setup test book with exactly 1 unit in stock
UPDATE dbo.Book SET StockQuantity = 1 WHERE BookID = 21;
SELECT BookID, Title, StockQuantity FROM dbo.Book WHERE BookID = 21;
GO

/*
-- [Session 1 Script]
USE BookStore;
BEGIN TRANSACTION;
    -- Query check followed by delay simulating checkout processing
    SELECT StockQuantity FROM dbo.Book WITH (UPDLOCK) WHERE BookID = 21;
    WAITFOR DELAY '00:00:05';
    UPDATE dbo.Book SET StockQuantity = StockQuantity - 1 WHERE BookID = 21;
COMMIT TRANSACTION;
SELECT BookID, StockQuantity FROM dbo.Book WHERE BookID = 21;

-- [Session 2 Script]
USE BookStore;
BEGIN TRANSACTION;
    -- Blocked by Session 1's UPDLOCK until Session 1 completes
    BEGIN TRY
        SELECT StockQuantity FROM dbo.Book WITH (UPDLOCK) WHERE BookID = 21;
        UPDATE dbo.Book SET StockQuantity = StockQuantity - 1 WHERE BookID = 21;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        -- CK_Book_Stock prevents stock from dropping below 0
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH;
*/


-- ============================================================================
-- Section 2: Isolation Levels Comparison (Non-Repeatable Read & Phantom Read)
-- ============================================================================

-- 2.1. READ COMMITTED vs REPEATABLE READ (Non-Repeatable Read)
-- Under READ COMMITTED, reading the same row twice within a transaction can yield different values.
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
    SELECT Price FROM dbo.Book WHERE BookID = 1;
    -- If another session updates Book 1 price here, the next select reads modified data
    -- WAITFOR DELAY '00:00:05';
    SELECT Price FROM dbo.Book WHERE BookID = 1;
COMMIT TRANSACTION;
GO

-- Under REPEATABLE READ, shared locks are held until transaction end, preventing modifications.
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
    SELECT Price FROM dbo.Book WHERE BookID = 1;
    -- Concurrent updates on Book 1 are blocked until commit
    SELECT Price FROM dbo.Book WHERE BookID = 1;
COMMIT TRANSACTION;
GO


-- ============================================================================
-- Section 3: Deadlock Simulation & Resolution
-- Two sessions updating records in reverse order trigger SQL Server Deadlock (Error 1205)
-- ============================================================================

/*
-- [Deadlock Session A]
USE BookStore;
BEGIN TRANSACTION;
    UPDATE dbo.Book SET Price = Price + 1000 WHERE BookID = 1;
    WAITFOR DELAY '00:00:05';
    UPDATE dbo.Book SET Price = Price + 1000 WHERE BookID = 2;
COMMIT TRANSACTION;

-- [Deadlock Session B]
USE BookStore;
BEGIN TRANSACTION;
    UPDATE dbo.Book SET Price = Price + 2000 WHERE BookID = 2;
    WAITFOR DELAY '00:00:05';
    UPDATE dbo.Book SET Price = Price + 2000 WHERE BookID = 1;
COMMIT TRANSACTION;

-- Resolution Strategy:
-- 1. Enforce strict alphabetical or numeric ordering of resource locks (always lock Book 1 before Book 2).
-- 2. Handle Error 1205 in application layer with automatic retry logic.
*/


-- ============================================================================
-- Section 4: Disaster Recovery (Full Database Backup & Restoration)
-- Uses dynamic path resolution for instance backup directory (compatible with SQLEXPRESS)
-- ============================================================================

-- 4.1. Create full database backup
DECLARE @BackupDir NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(400));
DECLARE @BackupFile NVARCHAR(500) = CASE WHEN RIGHT(@BackupDir, 1) = '\' THEN @BackupDir ELSE @BackupDir + '\' END + N'BookStore.bak';

BACKUP DATABASE BookStore
TO DISK = @BackupFile
WITH FORMAT, INIT, NAME = N'BookStore-Full Database Backup';
GO

-- 4.2. Verify backup file header
DECLARE @BackupDir NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(400));
DECLARE @BackupFile NVARCHAR(500) = CASE WHEN RIGHT(@BackupDir, 1) = '\' THEN @BackupDir ELSE @BackupDir + '\' END + N'BookStore.bak';

RESTORE HEADERONLY
FROM DISK = @BackupFile;
GO

-- 4.3. Restore database from backup file (reference template)
/*
USE master;
DECLARE @BackupDir NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(400));
DECLARE @BackupFile NVARCHAR(500) = CASE WHEN RIGHT(@BackupDir, 1) = '\' THEN @BackupDir ELSE @BackupDir + '\' END + N'BookStore.bak';

ALTER DATABASE BookStore SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE BookStore
FROM DISK = @BackupFile
WITH REPLACE;
ALTER DATABASE BookStore SET MULTI_USER;
*/
GO
