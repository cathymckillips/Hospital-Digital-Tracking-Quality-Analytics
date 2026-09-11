USE HospitalDigitalAnalytics;
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
