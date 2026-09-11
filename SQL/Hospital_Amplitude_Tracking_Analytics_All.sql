/* ============================================================
   Hospital Digital Tracking Analytics
   SQL Server / T-SQL
   Synthetic portfolio project
   ============================================================ */

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

/* ============================================================
   02. EVENT ALIAS / NORMALIZATION MAP
   This represents steward-approved mappings from messy names
   to the governed canonical event dictionary.
   ============================================================ */

DROP TABLE IF EXISTS governed.Event_Alias_Map;
CREATE TABLE governed.Event_Alias_Map (
    Source_Event_Name varchar(150) NOT NULL PRIMARY KEY,
    Canonical_Event   varchar(150) NOT NULL,
    Mapping_Reason    varchar(250) NULL
);

INSERT INTO governed.Event_Alias_Map (Source_Event_Name, Canonical_Event, Mapping_Reason)
VALUES
('find_care_click','find_care_click','Canonical'),
('Find Care Click','find_care_click','Spacing/case variant'),
('find-care-click','find_care_click','Delimiter variant'),
('Find_A_Doctor_Click','find_care_click','Legacy business wording'),
('findCareClick','find_care_click','CamelCase variant'),

('provider_search','provider_search','Canonical'),
('Provider Search','provider_search','Spacing/case variant'),
('provider-search','provider_search','Delimiter variant'),
('provider_serach','provider_search','Typo'),
('provider_clk','provider_search','Post-release implementation alias'),

('provider_profile_view','provider_profile_view','Canonical'),
('Provider Profile View','provider_profile_view','Spacing/case variant'),
('provider-profile-view','provider_profile_view','Delimiter variant'),
('providerProfileView','provider_profile_view','CamelCase variant'),

('schedule_click','schedule_click','Canonical'),
('schedule-click','schedule_click','Delimiter variant'),
('ScheduleClick','schedule_click','CamelCase variant'),
('click_schedule','schedule_click','Reversed wording'),
('schedule now click','schedule_click','Business wording'),
('scheduleNow','schedule_click','Legacy component name'),

('scheduling_started','scheduling_started','Canonical'),
('Scheduling Started','scheduling_started','Spacing/case variant'),
('scheduling-start','scheduling_started','Delimiter variant'),
('start_scheduling','scheduling_started','Wording variant'),

('appointment_completed','appointment_completed','Canonical'),
('Appointment Completed','appointment_completed','Spacing/case variant'),
('appointment-complete','appointment_completed','Delimiter variant'),
('appt_complete','appointment_completed','Abbreviation'),

('provider_call_click','provider_call_click','Canonical'),
('Provider Call Click','provider_call_click','Spacing/case variant'),
('call_provider','provider_call_click','Wording variant'),
('provider-phone-click','provider_call_click','Delimiter variant'),

('service_line_view','service_line_view','Canonical'),
('Service Line View','service_line_view','Spacing/case variant'),
('service-line-view','service_line_view','Delimiter variant'),

('cta_click','cta_click','Canonical'),
('CTA Click','cta_click','Spacing/case variant'),
('generic_cta_click','cta_click','Legacy wording'),
('button_click','cta_click','Generic legacy wording'),

('insurance_check_click','insurance_check_click','Canonical'),
('Insurance Check Click','insurance_check_click','Spacing/case variant'),
('insurance-check','insurance_check_click','Delimiter variant'),

('virtual_care_click','virtual_care_click','Canonical'),
('Virtual Care Click','virtual_care_click','Spacing/case variant'),
('virtual-care-click','virtual_care_click','Delimiter variant');
GO

/* ============================================================
   03. STAGING VIEWS
   ============================================================ */

CREATE OR ALTER VIEW staging.vw_AmplitudeEvents AS
SELECT
    NULLIF(LTRIM(RTRIM(Event_ID)), '') AS Event_ID,
    NULLIF(LTRIM(RTRIM(User_ID)), '') AS User_ID,
    NULLIF(LTRIM(RTRIM(Session_ID)), '') AS Session_ID,
    TRY_CONVERT(datetime2(0), NULLIF(LTRIM(RTRIM(Event_Timestamp)), '')) AS Event_Timestamp,
    NULLIF(LTRIM(RTRIM(Event_Name)), '') AS Raw_Event_Name,
    COALESCE(m.Canonical_Event, LOWER(REPLACE(REPLACE(LTRIM(RTRIM(a.Event_Name)),' ','_'),'-','_'))) AS Standardized_Event_Name,
    NULLIF(LOWER(LTRIM(RTRIM(Page_Name))), '') AS Page_Name,
    NULLIF(LOWER(LTRIM(RTRIM(Element_Name))), '') AS Element_Name,
    CASE
        WHEN LOWER(LTRIM(RTRIM(Device_Type))) IN ('mobile','phone','mobile-web') THEN 'Mobile'
        WHEN LOWER(LTRIM(RTRIM(Device_Type))) IN ('desktop','pc') THEN 'Desktop'
        WHEN LOWER(LTRIM(RTRIM(Device_Type))) = 'tablet' THEN 'Tablet'
        WHEN NULLIF(LTRIM(RTRIM(Device_Type)), '') IS NULL THEN NULL
        ELSE 'Invalid'
    END AS Device_Type,
    CASE
        WHEN LOWER(REPLACE(LTRIM(RTRIM(Service_Line)),' ','')) IN ('cardiology','cardiolgy') THEN 'Cardiology'
        WHEN LOWER(REPLACE(LTRIM(RTRIM(Service_Line)),' ','')) IN ('orthopedics','ortho') THEN 'Orthopedics'
        WHEN LOWER(REPLACE(LTRIM(RTRIM(Service_Line)),' ','')) = 'primarycare' THEN 'Primary Care'
        WHEN LOWER(REPLACE(LTRIM(RTRIM(Service_Line)),' ','')) = 'dermatology' THEN 'Dermatology'
        WHEN LOWER(REPLACE(REPLACE(LTRIM(RTRIM(Service_Line)),'''',''),' ','')) IN ('womenshealth','womenhealth') THEN 'Women''s Health'
        WHEN LOWER(REPLACE(LTRIM(RTRIM(Service_Line)),' ','')) = 'neurology' THEN 'Neurology'
        WHEN LOWER(REPLACE(LTRIM(RTRIM(Service_Line)),' ','')) = 'pediatrics' THEN 'Pediatrics'
        WHEN NULLIF(LTRIM(RTRIM(Service_Line)), '') IS NULL THEN NULL
        ELSE 'Invalid'
    END AS Service_Line,
    NULLIF(LTRIM(RTRIM(Acquisition_Channel)), '') AS Acquisition_Channel,
    NULLIF(LTRIM(RTRIM(Search_Type)), '') AS Search_Type,
    NULLIF(LTRIM(RTRIM(Provider_ID)), '') AS Provider_ID,
    NULLIF(LTRIM(RTRIM(Location_ID)), '') AS Location_ID,
    NULLIF(LTRIM(RTRIM(Appointment_Type)), '') AS Appointment_Type,
    NULLIF(LTRIM(RTRIM(Abandonment_Step)), '') AS Abandonment_Step,
    NULLIF(LTRIM(RTRIM(Form_Name)), '') AS Form_Name,
    NULLIF(LTRIM(RTRIM(Platform)), '') AS Platform
FROM raw.Amplitude_Events a
LEFT JOIN governed.Event_Alias_Map m
    ON LTRIM(RTRIM(a.Event_Name)) = m.Source_Event_Name;
GO

CREATE OR ALTER VIEW staging.vw_InternalTrackingLog AS
SELECT
    NULLIF(LTRIM(RTRIM(Tracking_ID)), '') AS Tracking_ID,
    NULLIF(LTRIM(RTRIM(Tracked_Event_Name)), '') AS Raw_Tracked_Event_Name,
    COALESCE(m.Canonical_Event, LOWER(REPLACE(REPLACE(LTRIM(RTRIM(t.Tracked_Event_Name)),' ','_'),'-','_'))) AS Standardized_Event_Name,
    NULLIF(LOWER(LTRIM(RTRIM(Page_Name))), '') AS Page_Name,
    NULLIF(LOWER(LTRIM(RTRIM(Element_Name))), '') AS Element_Name,
    CASE
        WHEN LOWER(LTRIM(RTRIM(Tracking_Status))) IN ('active','in production','production') THEN 'Active'
        WHEN LOWER(LTRIM(RTRIM(Tracking_Status))) IN ('old','deprecated') THEN 'Deprecated'
        WHEN NULLIF(LTRIM(RTRIM(Tracking_Status)), '') IS NULL THEN 'Unknown'
        ELSE LTRIM(RTRIM(Tracking_Status))
    END AS Tracking_Status,
    NULLIF(LTRIM(RTRIM(Owner)), '') AS Owner,
    TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(Implementation_Date)), '')) AS Implementation_Date,
    TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(Last_Validated_Date)), '')) AS Last_Validated_Date,
    Notes,
    NULLIF(LTRIM(RTRIM(Platform)), '') AS Platform
FROM raw.Internal_Tracking_Log t
LEFT JOIN governed.Event_Alias_Map m
    ON LTRIM(RTRIM(t.Tracked_Event_Name)) = m.Source_Event_Name;
GO

CREATE OR ALTER VIEW staging.vw_TrackingStandards AS
SELECT
    LOWER(LTRIM(RTRIM(Canonical_Event))) AS Canonical_Event,
    NULLIF(LTRIM(RTRIM(Event_Category)), '') AS Event_Category,
    NULLIF(LTRIM(RTRIM(Business_Definition)), '') AS Business_Definition,
    NULLIF(LOWER(LTRIM(RTRIM(Expected_Page))), '') AS Expected_Page,
    NULLIF(LOWER(LTRIM(RTRIM(Expected_Element))), '') AS Expected_Element,
    NULLIF(LTRIM(RTRIM(Business_Owner)), '') AS Business_Owner,
    NULLIF(LTRIM(RTRIM(Lifecycle_Status)), '') AS Lifecycle_Status,
    NULLIF(LTRIM(RTRIM(Required_Properties)), '') AS Required_Properties
FROM raw.Tracking_Event_Standards;
GO

CREATE OR ALTER VIEW staging.vw_WebsiteReleaseLog AS
SELECT
    NULLIF(LTRIM(RTRIM(Release_ID)), '') AS Release_ID,
    TRY_CONVERT(datetime2(0), NULLIF(LTRIM(RTRIM(Release_Timestamp)), '')) AS Release_Timestamp,
    NULLIF(LTRIM(RTRIM(Release_Name)), '') AS Release_Name,
    NULLIF(LOWER(LTRIM(RTRIM(Affected_Area))), '') AS Affected_Area,
    NULLIF(LTRIM(RTRIM(Technical_Owner)), '') AS Technical_Owner,
    NULLIF(LTRIM(RTRIM(Release_Status)), '') AS Release_Status,
    Notes
FROM raw.Website_Release_Log;
GO

/* ============================================================
   04. DATA QUALITY EXCEPTIONS
   One unified view suitable for Power BI.
   ============================================================ */

CREATE OR ALTER VIEW governed.vw_TrackingDQExceptions AS

/* DQ01: observed Amplitude event not in governed standards */
SELECT
    'DQ01' AS DQ_Rule,
    'High' AS Severity,
    'Undocumented Amplitude event' AS Issue_Type,
    a.Event_ID AS Record_ID,
    a.Standardized_Event_Name AS Event_Name,
    a.Event_Timestamp AS Issue_Timestamp,
    CONCAT('Observed event "', COALESCE(a.Raw_Event_Name,'NULL'), '" is not in governed Tracking_Event_Standards.') AS Issue_Description,
    CAST(NULL AS varchar(150)) AS Assigned_Owner
FROM staging.vw_AmplitudeEvents a
LEFT JOIN staging.vw_TrackingStandards s
    ON a.Standardized_Event_Name = s.Canonical_Event
WHERE s.Canonical_Event IS NULL

UNION ALL

/* DQ02: active standard documented but has no observed activity */
SELECT
    'DQ02','High','Documented event has no Amplitude activity',
    s.Canonical_Event,
    s.Canonical_Event,
    NULL,
    'Active governed event has zero observed Amplitude events in the loaded period.',
    s.Business_Owner
FROM staging.vw_TrackingStandards s
LEFT JOIN staging.vw_AmplitudeEvents a
    ON s.Canonical_Event = a.Standardized_Event_Name
WHERE s.Lifecycle_Status='Active'
GROUP BY s.Canonical_Event, s.Business_Owner
HAVING COUNT(a.Event_ID)=0

UNION ALL

/* DQ03: duplicated Tracking_ID */
SELECT
    'DQ03','High','Duplicate tracking ID',
    t.Tracking_ID,
    MIN(t.Standardized_Event_Name),
    NULL,
    CONCAT('Tracking_ID appears ', COUNT(*), ' times in the internal tracking log.'),
    MIN(t.Owner)
FROM staging.vw_InternalTrackingLog t
WHERE t.Tracking_ID IS NOT NULL
GROUP BY t.Tracking_ID
HAVING COUNT(*) > 1

UNION ALL

/* DQ04: missing owner */
SELECT
    'DQ04','Medium','Missing tracking owner',
    t.Tracking_ID,
    t.Standardized_Event_Name,
    NULL,
    'Internal tracking log entry has no assigned owner.',
    NULL
FROM staging.vw_InternalTrackingLog t
WHERE t.Owner IS NULL

UNION ALL

/* DQ05: noncanonical/raw naming */
SELECT
    'DQ05','Medium','Nonstandard event naming',
    t.Tracking_ID,
    t.Standardized_Event_Name,
    NULL,
    CONCAT('Raw tracking name "', t.Raw_Tracked_Event_Name, '" differs from canonical "', t.Standardized_Event_Name, '".'),
    t.Owner
FROM staging.vw_InternalTrackingLog t
WHERE t.Raw_Tracked_Event_Name <> t.Standardized_Event_Name

UNION ALL

/* DQ06: required property missing in Amplitude */
SELECT
    'DQ06','High','Missing required event property',
    a.Event_ID,
    a.Standardized_Event_Name,
    a.Event_Timestamp,
    CONCAT('Required property missing. Page=', COALESCE(a.Page_Name,'NULL'),
           '; Element=', COALESCE(a.Element_Name,'NULL'),
           '; User=', COALESCE(a.User_ID,'NULL'),
           '; Device=', COALESCE(a.Device_Type,'NULL')),
    s.Business_Owner
FROM staging.vw_AmplitudeEvents a
JOIN staging.vw_TrackingStandards s
  ON a.Standardized_Event_Name=s.Canonical_Event
WHERE
    a.User_ID IS NULL
    OR a.Device_Type IS NULL
    OR (s.Required_Properties LIKE '%page_name%' AND a.Page_Name IS NULL)
    OR (s.Required_Properties LIKE '%element_name%' AND a.Element_Name IS NULL)

UNION ALL

/* DQ07: deprecated event still firing */
SELECT
    'DQ07','High','Deprecated event still firing',
    a.Event_ID,
    a.Standardized_Event_Name,
    a.Event_Timestamp,
    'Amplitude received an event whose governed lifecycle status is Deprecated.',
    s.Business_Owner
FROM staging.vw_AmplitudeEvents a
JOIN staging.vw_TrackingStandards s
  ON a.Standardized_Event_Name=s.Canonical_Event
WHERE s.Lifecycle_Status='Deprecated'

UNION ALL

/* DQ08: invalid service line */
SELECT
    'DQ08','Medium','Invalid service line',
    a.Event_ID,
    a.Standardized_Event_Name,
    a.Event_Timestamp,
    'Service line could not be mapped to the approved service-line list.',
    NULL
FROM staging.vw_AmplitudeEvents a
WHERE a.Service_Line='Invalid'

UNION ALL

/* DQ09: potential duplicate firing within 1 second */
SELECT
    'DQ09','Critical','Potential duplicate event firing',
    a.Event_ID,
    a.Standardized_Event_Name,
    a.Event_Timestamp,
    'Same user/session/event/page/element observed within one second of another event.',
    s.Business_Owner
FROM staging.vw_AmplitudeEvents a
JOIN staging.vw_AmplitudeEvents b
  ON a.Event_ID <> b.Event_ID
 AND ISNULL(a.User_ID,'') = ISNULL(b.User_ID,'')
 AND ISNULL(a.Session_ID,'') = ISNULL(b.Session_ID,'')
 AND ISNULL(a.Standardized_Event_Name,'') = ISNULL(b.Standardized_Event_Name,'')
 AND ISNULL(a.Page_Name,'') = ISNULL(b.Page_Name,'')
 AND ISNULL(a.Element_Name,'') = ISNULL(b.Element_Name,'')
 AND ABS(DATEDIFF(second,a.Event_Timestamp,b.Event_Timestamp)) <= 1
LEFT JOIN staging.vw_TrackingStandards s
 ON a.Standardized_Event_Name=s.Canonical_Event

UNION ALL

/* DQ10: future timestamp */
SELECT
    'DQ10','High','Future event timestamp',
    a.Event_ID,
    a.Standardized_Event_Name,
    a.Event_Timestamp,
    'Event timestamp is later than the project as-of date 2026-09-09.',
    s.Business_Owner
FROM staging.vw_AmplitudeEvents a
LEFT JOIN staging.vw_TrackingStandards s
 ON a.Standardized_Event_Name=s.Canonical_Event
WHERE a.Event_Timestamp > CAST('2026-09-09T23:59:59' AS datetime2)

UNION ALL

/* DQ11: invalid device */
SELECT
    'DQ11','Medium','Invalid device category',
    a.Event_ID,
    a.Standardized_Event_Name,
    a.Event_Timestamp,
    'Device value could not be mapped to Mobile, Desktop, or Tablet.',
    s.Business_Owner
FROM staging.vw_AmplitudeEvents a
LEFT JOIN staging.vw_TrackingStandards s
 ON a.Standardized_Event_Name=s.Canonical_Event
WHERE a.Device_Type='Invalid'

UNION ALL

/* DQ12: active internal tracking log event not governed */
SELECT
    'DQ12','High','Internal log event not governed',
    t.Tracking_ID,
    t.Standardized_Event_Name,
    NULL,
    CONCAT('Active internal tracking entry "',t.Raw_Tracked_Event_Name,'" has no governed event definition.'),
    t.Owner
FROM staging.vw_InternalTrackingLog t
LEFT JOIN staging.vw_TrackingStandards s
 ON t.Standardized_Event_Name=s.Canonical_Event
WHERE t.Tracking_Status='Active'
  AND s.Canonical_Event IS NULL;
GO

/* ============================================================
   05. EVENT COVERAGE / RECONCILIATION
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_EventCoverage AS
WITH observed AS (
    SELECT Standardized_Event_Name, COUNT(*) AS Observed_Event_Count,
           MIN(Event_Timestamp) AS First_Observed,
           MAX(Event_Timestamp) AS Last_Observed
    FROM staging.vw_AmplitudeEvents
    GROUP BY Standardized_Event_Name
),
internal_log AS (
    SELECT Standardized_Event_Name,
           COUNT(*) AS Tracking_Log_Rows,
           COUNT(DISTINCT Tracking_ID) AS Distinct_Tracking_IDs,
           MAX(CASE WHEN Tracking_Status='Active' THEN 1 ELSE 0 END) AS Has_Active_Log_Definition
    FROM staging.vw_InternalTrackingLog
    GROUP BY Standardized_Event_Name
)
SELECT
    COALESCE(s.Canonical_Event,o.Standardized_Event_Name,l.Standardized_Event_Name) AS Event_Name,
    s.Event_Category,
    s.Business_Definition,
    s.Business_Owner,
    s.Lifecycle_Status,
    ISNULL(l.Tracking_Log_Rows,0) AS Tracking_Log_Rows,
    ISNULL(l.Distinct_Tracking_IDs,0) AS Distinct_Tracking_IDs,
    ISNULL(o.Observed_Event_Count,0) AS Observed_Event_Count,
    o.First_Observed,
    o.Last_Observed,
    CASE
        WHEN s.Canonical_Event IS NULL AND o.Standardized_Event_Name IS NOT NULL THEN 'Observed / Not Governed'
        WHEN s.Canonical_Event IS NOT NULL AND ISNULL(o.Observed_Event_Count,0)=0 THEN 'Governed / Not Observed'
        WHEN s.Lifecycle_Status='Deprecated' AND ISNULL(o.Observed_Event_Count,0)>0 THEN 'Deprecated / Still Firing'
        WHEN s.Canonical_Event IS NOT NULL AND ISNULL(o.Observed_Event_Count,0)>0 THEN 'Matched'
        ELSE 'Review'
    END AS Coverage_Status
FROM staging.vw_TrackingStandards s
FULL OUTER JOIN observed o
  ON s.Canonical_Event=o.Standardized_Event_Name
FULL OUTER JOIN internal_log l
  ON COALESCE(s.Canonical_Event,o.Standardized_Event_Name)=l.Standardized_Event_Name;
GO

/* ============================================================
   06. DAILY EVENT HEALTH / ANOMALY INPUT
   Rolling 7-day baseline by event + device.
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_DailyEventHealth AS
WITH daily AS (
    SELECT
        CAST(Event_Timestamp AS date) AS Event_Date,
        Standardized_Event_Name AS Event_Name,
        Device_Type,
        COUNT(*) AS Event_Count
    FROM staging.vw_AmplitudeEvents
    WHERE Event_Timestamp IS NOT NULL
      AND Event_Timestamp <= '2026-09-09T23:59:59'
    GROUP BY CAST(Event_Timestamp AS date), Standardized_Event_Name, Device_Type
),
x AS (
    SELECT *,
        AVG(CAST(Event_Count AS decimal(18,2))) OVER (
            PARTITION BY Event_Name, Device_Type
            ORDER BY Event_Date
            ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
        ) AS Prior_7_Day_Avg,
        STDEV(CAST(Event_Count AS decimal(18,2))) OVER (
            PARTITION BY Event_Name, Device_Type
            ORDER BY Event_Date
            ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
        ) AS Prior_7_Day_SD
    FROM daily
)
SELECT *,
    CASE WHEN Prior_7_Day_Avg IS NULL OR Prior_7_Day_Avg=0 THEN NULL
         ELSE (Event_Count-Prior_7_Day_Avg)/Prior_7_Day_Avg END AS Variance_Pct,
    CASE
        WHEN Prior_7_Day_Avg IS NULL THEN 'Insufficient History'
        WHEN Event_Count < Prior_7_Day_Avg*0.50 THEN 'Critical Drop'
        WHEN Event_Count > Prior_7_Day_Avg*1.75 THEN 'Critical Spike'
        WHEN Event_Count < Prior_7_Day_Avg*0.75 THEN 'Warning Drop'
        WHEN Event_Count > Prior_7_Day_Avg*1.40 THEN 'Warning Spike'
        ELSE 'Normal'
    END AS Volume_Health_Flag
FROM x;
GO

/* ============================================================
   07. RELEASE IMPACT VIEW
   Compare 7 days before vs 7 days after each release.
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_ReleaseImpact AS
SELECT
    r.Release_ID,
    r.Release_Timestamp,
    r.Release_Name,
    r.Affected_Area,
    r.Technical_Owner,
    a.Standardized_Event_Name AS Event_Name,
    a.Device_Type,
    SUM(CASE WHEN a.Event_Timestamp >= DATEADD(day,-7,r.Release_Timestamp)
              AND a.Event_Timestamp < r.Release_Timestamp THEN 1 ELSE 0 END) AS Events_7D_Pre,
    SUM(CASE WHEN a.Event_Timestamp >= r.Release_Timestamp
              AND a.Event_Timestamp < DATEADD(day,7,r.Release_Timestamp) THEN 1 ELSE 0 END) AS Events_7D_Post
FROM staging.vw_WebsiteReleaseLog r
JOIN staging.vw_AmplitudeEvents a
  ON a.Event_Timestamp >= DATEADD(day,-7,r.Release_Timestamp)
 AND a.Event_Timestamp < DATEADD(day,7,r.Release_Timestamp)
GROUP BY
    r.Release_ID,r.Release_Timestamp,r.Release_Name,r.Affected_Area,r.Technical_Owner,
    a.Standardized_Event_Name,a.Device_Type;
GO

/* ============================================================
   08. PATIENT JOURNEY / FUNNEL AGGREGATES
   Note: synthetic anonymous IDs only; no PHI.
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_DigitalJourneyDaily AS
SELECT
    CAST(Event_Timestamp AS date) AS Event_Date,
    Device_Type,
    Service_Line,
    Acquisition_Channel,
    COUNT(DISTINCT CASE WHEN Standardized_Event_Name='homepage_view' THEN Session_ID END) AS Homepage_Sessions,
    COUNT(DISTINCT CASE WHEN Standardized_Event_Name='find_care_click' THEN Session_ID END) AS Find_Care_Sessions,
    COUNT(DISTINCT CASE WHEN Standardized_Event_Name='provider_search' THEN Session_ID END) AS Provider_Search_Sessions,
    COUNT(DISTINCT CASE WHEN Standardized_Event_Name='provider_profile_view' THEN Session_ID END) AS Provider_Profile_Sessions,
    COUNT(DISTINCT CASE WHEN Standardized_Event_Name='schedule_click' THEN Session_ID END) AS Schedule_Click_Sessions,
    COUNT(DISTINCT CASE WHEN Standardized_Event_Name='scheduling_started' THEN Session_ID END) AS Scheduling_Started_Sessions,
    COUNT(DISTINCT CASE WHEN Standardized_Event_Name='appointment_completed' THEN Session_ID END) AS Appointment_Completed_Sessions,
    COUNT(DISTINCT CASE WHEN Standardized_Event_Name='schedule_abandoned' THEN Session_ID END) AS Abandoned_Sessions
FROM staging.vw_AmplitudeEvents
WHERE Event_Timestamp <= '2026-09-09T23:59:59'
GROUP BY CAST(Event_Timestamp AS date),Device_Type,Service_Line,Acquisition_Channel;
GO

/* ============================================================
   09. TRACKING HEALTH SCORECARD
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_TrackingHealthScorecard AS
WITH exception_counts AS (
    SELECT
        COUNT(*) AS Total_Exceptions,
        SUM(CASE WHEN Severity='Critical' THEN 1 ELSE 0 END) AS Critical_Exceptions,
        SUM(CASE WHEN Severity='High' THEN 1 ELSE 0 END) AS High_Exceptions,
        SUM(CASE WHEN Severity='Medium' THEN 1 ELSE 0 END) AS Medium_Exceptions
    FROM governed.vw_TrackingDQExceptions
),
coverage AS (
    SELECT
        COUNT(*) AS Total_Governed_Events,
        SUM(CASE WHEN Coverage_Status='Matched' THEN 1 ELSE 0 END) AS Matched_Events,
        SUM(CASE WHEN Coverage_Status='Governed / Not Observed' THEN 1 ELSE 0 END) AS Missing_Observed_Events,
        SUM(CASE WHEN Coverage_Status='Observed / Not Governed' THEN 1 ELSE 0 END) AS Ungoverned_Observed_Events,
        SUM(CASE WHEN Coverage_Status='Deprecated / Still Firing' THEN 1 ELSE 0 END) AS Deprecated_Firing
    FROM reporting.vw_EventCoverage
),
events AS (
    SELECT COUNT(*) AS Total_Amplitude_Events
    FROM staging.vw_AmplitudeEvents
)
SELECT
    e.Total_Amplitude_Events,
    c.Total_Governed_Events,
    c.Matched_Events,
    c.Missing_Observed_Events,
    c.Ungoverned_Observed_Events,
    c.Deprecated_Firing,
    x.Total_Exceptions,
    x.Critical_Exceptions,
    x.High_Exceptions,
    x.Medium_Exceptions,
    CAST(100.0 * c.Matched_Events / NULLIF(c.Total_Governed_Events,0) AS decimal(5,1)) AS Specification_Match_Pct,
    CAST(
       100.0 -
       CASE WHEN e.Total_Amplitude_Events=0 THEN 0
            ELSE 100.0 * (
                x.Critical_Exceptions*4.0 +
                x.High_Exceptions*2.0 +
                x.Medium_Exceptions*0.5
            ) / e.Total_Amplitude_Events
       END
       AS decimal(5,1)
    ) AS Tracking_Health_Score
FROM exception_counts x
CROSS JOIN coverage c
CROSS JOIN events e;
GO

/* ============================================================
   10. USEFUL ANALYSIS QUERIES
   ============================================================ */

-- A. Which Amplitude events are not governed?
SELECT Event_Name, COUNT(*) AS Event_Count
FROM governed.vw_TrackingDQExceptions
WHERE DQ_Rule='DQ01'
GROUP BY Event_Name
ORDER BY Event_Count DESC;

-- B. Which governed events never fired?
SELECT *
FROM reporting.vw_EventCoverage
WHERE Coverage_Status='Governed / Not Observed';

-- C. Which deprecated events still fire?
SELECT *
FROM reporting.vw_EventCoverage
WHERE Coverage_Status='Deprecated / Still Firing';

-- D. Highest-volume DQ issues
SELECT DQ_Rule, Issue_Type, Severity, COUNT(*) AS Exception_Count
FROM governed.vw_TrackingDQExceptions
GROUP BY DQ_Rule, Issue_Type, Severity
ORDER BY Exception_Count DESC;

-- E. Mobile schedule_click trend around Aug 18 release
SELECT Event_Date, Event_Name, Device_Type, Event_Count, Prior_7_Day_Avg,
       Variance_Pct, Volume_Health_Flag
FROM reporting.vw_DailyEventHealth
WHERE Event_Name='schedule_click'
  AND Device_Type='Mobile'
  AND Event_Date BETWEEN '2026-08-10' AND '2026-08-30'
ORDER BY Event_Date;

-- F. Release impact around scheduling JS bundle update
SELECT *,
       CAST(100.0*(Events_7D_Post-Events_7D_Pre)/NULLIF(Events_7D_Pre,0) AS decimal(8,1)) AS Change_Pct
FROM reporting.vw_ReleaseImpact
WHERE Release_ID='REL-2608-02'
  AND Event_Name IN ('schedule_click','scheduling_started','appointment_completed')
ORDER BY Event_Name, Device_Type;

-- G. Daily funnel
SELECT *
FROM reporting.vw_DigitalJourneyDaily
ORDER BY Event_Date DESC;

-- H. Executive tracking health
SELECT *
FROM reporting.vw_TrackingHealthScorecard;
GO
