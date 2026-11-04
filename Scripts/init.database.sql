/*
===============================================================================
WARNING: DESTRUCTIVE SCRIPT
===============================================================================
Running this script will PERMANENTLY DROP the 'Datawarehouse' database if it 
already exists. All tables, schemas, views, and data stored inside it will be 
COMPLETELY DELETED.

Ensure you have saved any necessary scripts or backups before executing!
===============================================================================
*/

USE master;
GO

-- Drop and recreate the 'Datawarehouse' database safely
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'Datawarehouse')
BEGIN
    ALTER DATABASE Datawarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Datawarehouse;
END;
GO

-- Create the fresh 'Datawarehouse' database
CREATE DATABASE Datawarehouse;
GO

USE Datawarehouse;
GO

-- Create project schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
