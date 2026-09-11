USE HospitalDigitalAnalytics;
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
