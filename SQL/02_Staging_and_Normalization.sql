USE HospitalDigitalAnalytics;
GO

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
