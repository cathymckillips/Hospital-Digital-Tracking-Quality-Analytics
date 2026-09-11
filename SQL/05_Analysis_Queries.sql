USE HospitalDigitalAnalytics;
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
