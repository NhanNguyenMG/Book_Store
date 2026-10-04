USE master;
GO

IF DB_ID(N'BookStore') IS NULL
    CREATE DATABASE BookStore COLLATE Vietnamese_CI_AS;
GO

USE BookStore;
GO