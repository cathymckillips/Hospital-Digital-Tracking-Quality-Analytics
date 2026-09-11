IF DB_ID('HospitalDigitalAnalytics') IS NULL
    CREATE DATABASE HospitalDigitalAnalytics;
GO

USE HospitalDigitalAnalytics;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='raw') EXEC('CREATE SCHEMA raw');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='staging') EXEC('CREATE SCHEMA staging');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='governed') EXEC('CREATE SCHEMA governed');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='reporting') EXEC('CREATE SCHEMA reporting');
GO

/* ============================================================
   01. RAW TABLES
   ============================================================ */

DROP TABLE IF EXISTS raw.Amplitude_Events;
CREATE TABLE raw.Amplitude_Events (
    Event_ID             varchar(30)  NULL,
    User_ID              varchar(30)  NULL,
    Session_ID           varchar(30)  NULL,
    Event_Timestamp      varchar(30)  NULL,
    Event_Name           varchar(150) NULL,
    Page_Name            varchar(150) NULL,
    Element_Name         varchar(150) NULL,
    Device_Type          varchar(50)  NULL,
    Service_Line         varchar(100) NULL,
    Acquisition_Channel  varchar(100) NULL,
    Search_Type          varchar(100) NULL,
    Provider_ID          varchar(30)  NULL,
    Location_ID          varchar(100) NULL,
    Appointment_Type     varchar(100) NULL,
    Abandonment_Step     varchar(100) NULL,
    Form_Name            varchar(100) NULL,
    Platform             varchar(50)  NULL
);

DROP TABLE IF EXISTS raw.Internal_Tracking_Log;
CREATE TABLE raw.Internal_Tracking_Log (
    Tracking_ID          varchar(30)  NULL,
    Tracked_Event_Name   varchar(150) NULL,
    Page_Name            varchar(150) NULL,
    Element_Name         varchar(150) NULL,
    Tracking_Status      varchar(100) NULL,
    Owner                varchar(150) NULL,
    Implementation_Date  varchar(30)  NULL,
    Last_Validated_Date  varchar(30)  NULL,
    Notes                varchar(500) NULL,
    Platform             varchar(100) NULL
);

DROP TABLE IF EXISTS raw.Tracking_Event_Standards;
CREATE TABLE raw.Tracking_Event_Standards (
    Canonical_Event      varchar(150) NOT NULL,
    Event_Category       varchar(100) NULL,
    Business_Definition  varchar(500) NULL,
    Expected_Page        varchar(150) NULL,
    Expected_Element     varchar(150) NULL,
    Business_Owner       varchar(150) NULL,
    Lifecycle_Status     varchar(50)  NULL,
    Required_Properties  varchar(500) NULL
);

DROP TABLE IF EXISTS raw.Website_Release_Log;
CREATE TABLE raw.Website_Release_Log (
    Release_ID          varchar(30)  NULL,
    Release_Timestamp   varchar(30)  NULL,
    Release_Name        varchar(250) NULL,
    Affected_Area       varchar(150) NULL,
    Technical_Owner     varchar(150) NULL,
    Release_Status      varchar(50)  NULL,
    Notes               varchar(500) NULL
);
GO

/* IMPORT NOTE
   Import the four CSV files with SSMS Import Flat File / Import Data wizard.
   Load them into the raw tables above. Keeping raw columns as varchar preserves
   source defects for profiling and avoids failed loads from bad source values.
*/
