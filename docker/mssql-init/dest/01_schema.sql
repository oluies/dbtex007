IF DB_ID('ddd_dest') IS NULL
    CREATE DATABASE ddd_dest;
GO

USE ddd_dest;
GO

-- Tables are created by dbt (Project A creates them via pandas.to_sql,
-- Project B creates them via the DuckDB mssql extension's CREATE TABLE).
-- We pre-create only the schema to keep dbt-side configuration simple.
IF SCHEMA_ID('ddd') IS NULL
    EXEC('CREATE SCHEMA ddd');
GO
