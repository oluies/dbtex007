IF DB_ID('ddd_source') IS NULL
    CREATE DATABASE ddd_source;
GO

USE ddd_source;
GO

IF SCHEMA_ID('ddd') IS NULL
    EXEC('CREATE SCHEMA ddd');
GO

IF OBJECT_ID('ddd.handling_events', 'U') IS NOT NULL DROP TABLE ddd.handling_events;
IF OBJECT_ID('ddd.legs',            'U') IS NOT NULL DROP TABLE ddd.legs;
IF OBJECT_ID('ddd.itinerary',       'U') IS NOT NULL DROP TABLE ddd.itinerary;
IF OBJECT_ID('ddd.cargo',           'U') IS NOT NULL DROP TABLE ddd.cargo;
IF OBJECT_ID('ddd.voyages',         'U') IS NOT NULL DROP TABLE ddd.voyages;
IF OBJECT_ID('ddd.locations',       'U') IS NOT NULL DROP TABLE ddd.locations;
GO

CREATE TABLE ddd.locations (
    unlocode CHAR(5)        NOT NULL PRIMARY KEY,
    name     NVARCHAR(100)  NOT NULL
);
GO

CREATE TABLE ddd.voyages (
    voyage_number NVARCHAR(20)  NOT NULL PRIMARY KEY,
    schedule_json NVARCHAR(MAX) NULL
);
GO

CREATE TABLE ddd.cargo (
    tracking_id            NVARCHAR(20) NOT NULL PRIMARY KEY,
    origin_unlocode        CHAR(5)      NOT NULL,
    destination_unlocode   CHAR(5)      NOT NULL,
    arrival_deadline       DATETIME2    NOT NULL,
    CONSTRAINT fk_cargo_origin      FOREIGN KEY (origin_unlocode)      REFERENCES ddd.locations(unlocode),
    CONSTRAINT fk_cargo_destination FOREIGN KEY (destination_unlocode) REFERENCES ddd.locations(unlocode)
);
GO

CREATE TABLE ddd.itinerary (
    cargo_tracking_id NVARCHAR(20) NOT NULL PRIMARY KEY,
    CONSTRAINT fk_itinerary_cargo FOREIGN KEY (cargo_tracking_id) REFERENCES ddd.cargo(tracking_id)
);
GO

CREATE TABLE ddd.legs (
    itinerary_cargo_tracking_id NVARCHAR(20) NOT NULL,
    leg_number                  INT          NOT NULL,
    voyage_number               NVARCHAR(20) NOT NULL,
    load_location               CHAR(5)      NOT NULL,
    unload_location             CHAR(5)      NOT NULL,
    load_time                   DATETIME2    NOT NULL,
    unload_time                 DATETIME2    NOT NULL,
    CONSTRAINT pk_legs                PRIMARY KEY (itinerary_cargo_tracking_id, leg_number),
    CONSTRAINT fk_legs_itinerary      FOREIGN KEY (itinerary_cargo_tracking_id) REFERENCES ddd.itinerary(cargo_tracking_id),
    CONSTRAINT fk_legs_voyage         FOREIGN KEY (voyage_number)               REFERENCES ddd.voyages(voyage_number),
    CONSTRAINT fk_legs_load_location  FOREIGN KEY (load_location)               REFERENCES ddd.locations(unlocode),
    CONSTRAINT fk_legs_unload_location FOREIGN KEY (unload_location)            REFERENCES ddd.locations(unlocode)
);
GO

CREATE TABLE ddd.handling_events (
    id                BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    event_type        NVARCHAR(20) NOT NULL,
    cargo_tracking_id NVARCHAR(20) NOT NULL,
    voyage_number     NVARCHAR(20) NULL,
    location_unlocode CHAR(5)      NOT NULL,
    completion_time   DATETIME2    NOT NULL,
    registration_time DATETIME2    NOT NULL,
    CONSTRAINT fk_he_cargo    FOREIGN KEY (cargo_tracking_id) REFERENCES ddd.cargo(tracking_id),
    CONSTRAINT fk_he_voyage   FOREIGN KEY (voyage_number)     REFERENCES ddd.voyages(voyage_number),
    CONSTRAINT fk_he_location FOREIGN KEY (location_unlocode) REFERENCES ddd.locations(unlocode)
);
GO
