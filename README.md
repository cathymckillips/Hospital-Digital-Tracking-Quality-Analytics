# Hospital Digital Tracking & Data Quality Analytics

## Project Overview

This project is an end-to-end **healthcare digital analytics and data quality solution** built using **SQL Server, Power BI, DAX, and synthetic Amplitude-style event data**.

The project simulates a hospital environment where **Amplitude** is the primary digital analytics platform, while an internal tracking log is used to document how website interactions are expected to be captured.

The challenge is that digital tracking data is not always clean or reliable. Event names may be inconsistent, required properties may be missing, deprecated events may continue firing, duplicate events may occur, and website releases may unintentionally affect tracking.

The purpose of this project is therefore not simply to build a dashboard. It is to answer a more fundamental analytics question:

> **Can we trust the digital tracking data before using it to make business decisions about patient behavior?**

The solution creates a governed framework for comparing **expected tracking against observed Amplitude activity**, identifying data-quality exceptions, monitoring event anomalies, evaluating potential release impacts, and analyzing the patient digital journey.

> **Important:** All data used in this project is synthetic and was created solely for portfolio and educational purposes. No PHI, PII, or real patient data is included.

---

## Business Problem

Healthcare organizations increasingly rely on digital analytics to understand how patients interact with websites and digital scheduling experiences.

However, reported behavior can be misleading when the underlying tracking implementation is incomplete or inconsistent.

For example, suppose the number of patients clicking a **Schedule Appointment** button suddenly declines.

That could mean:

- fewer patients are attempting to schedule appointments;
- an event was renamed without updating the tracking specification;
- a JavaScript deployment affected event collection;
- the event stopped firing on a specific device;
- duplicate or malformed tracking altered the reported metrics; or
- the tracking implementation no longer matches the organization's governed event definitions.

Before interpreting a change as patient behavior, the integrity of the tracking data must be evaluated.

This project was designed around that distinction:

> **Did patient behavior change, or did the tracking implementation change?**

---

## Project Objectives

The solution was designed to:

- Create a governed digital event tracking framework.
- Standardize inconsistent event names.
- Compare internal tracking specifications with observed Amplitude events.
- Identify undocumented, missing, duplicate, and deprecated events.
- Detect missing required event properties.
- Identify invalid device and service-line values.
- Detect potential duplicate event firing.
- Monitor daily event volume against historical baselines.
- Evaluate event behavior before and after website releases.
- Analyze the patient digital journey after establishing confidence in tracking quality.
- Present technical data-quality findings in a business-friendly Power BI report.

---

## Technologies Used

| Technology | Purpose |
|---|---|
| **SQL Server** | Data storage, transformation, validation, governance, and reporting views |
| **T-SQL** | Data-quality rules, event normalization, analytical logic, and reporting datasets |
| **Power BI** | Interactive dashboards, KPI reporting, anomaly monitoring, and journey analysis |
| **DAX** | KPI calculations, conversion metrics, exception counts, and analytical measures |
| **Amplitude-style Event Data** | Synthetic digital behavioral analytics data |
| **CSV** | Synthetic source datasets |
| **GitHub** | Project documentation and source control |

---

# Solution Architecture

The project follows a layered analytics architecture.

```text
        AMPLITUDE EVENT DATA
                 +
       INTERNAL TRACKING LOG
                 +
      TRACKING EVENT STANDARDS
                 +
        WEBSITE RELEASE LOG
                 |
                 v
        +----------------+
        |   RAW LAYER    |
        +----------------+
                 |
                 v
        +----------------+
        |    STAGING     |
        | NORMALIZATION  |
        +----------------+
                 |
                 v
        +----------------+
        |    GOVERNED    |
        | EVENT + DQ     |
        +----------------+
                 |
                 v
        +----------------+
        |   REPORTING    |
        |     VIEWS      |
        +----------------+
                 |
                 v
        +----------------+
        |    POWER BI    |
        +----------------+
```

This structure preserves the original source data while progressively transforming it into standardized, governed, and reporting-ready datasets.

---

# Source Data

The project uses synthetic datasets representing several components of a hospital digital analytics environment.

## Amplitude Events

**File:** `data/Amplitude_Events.csv`

Contains approximately **72,000 synthetic digital events** representing interactions captured by an Amplitude-style analytics platform.

Examples include:

```text
homepage_view
find_care_click
provider_search
provider_profile_view
schedule_click
scheduling_started
appointment_completed
```

Event attributes include information such as:

- User
- Session
- Timestamp
- Event
- Page
- Element
- Device
- Service Line
- Acquisition Channel
- Provider
- Location
- Appointment Type
- Abandonment Step
- Platform

The dataset intentionally contains several tracking and data-quality problems so that they can be detected through SQL validation.

---

## Internal Tracking Log

**File:** `data/Internal_Tracking_Log.csv`

Represents an internal tracking inventory used to document expected website instrumentation.

The log intentionally contains realistic governance problems such as:

- inconsistent naming;
- duplicate tracking IDs;
- missing owners;
- legacy tracking definitions;
- deprecated events;
- inconsistent capitalization;
- whitespace;
- delimiters;
- typos; and
- tracking definitions requiring review.

This dataset represents the less-structured documentation that analysts may need to reconcile against actual digital event activity.

---

## Tracking Event Standards

**File:** `data/Tracking_Event_Standards.csv`

Represents the governed event dictionary and serves as the canonical source of truth for digital tracking.

It includes:

- Canonical Event
- Event Category
- Business Definition
- Expected Page
- Expected Element
- Business Owner
- Lifecycle Status
- Required Properties

The standards table allows expected tracking behavior to be compared with both the internal tracking log and observed Amplitude activity.

---

## Website Release Log

**File:** `data/Website_Release_Log.csv`

Contains synthetic website deployment history.

The release information is used to determine whether unusual changes in event volume coincide with technical deployments.

One seeded scenario includes an **August 18 scheduling JavaScript release** followed by a substantial decline in mobile `schedule_click` activity.

This creates an opportunity to investigate whether the decline represents a genuine behavioral change or a potential tracking regression.

---

## Data Quality Rules

**File:** `data/Data_Quality_Rules.csv`

Documents the data-quality controls used throughout the project.

The actual exception-detection logic is implemented in SQL.

---

# Data Quality Framework

Twelve data-quality rules were created to evaluate the tracking environment.

| Rule | Data Quality Check | Severity |
|---|---|---|
| **DQ01** | Observed Amplitude event not found in governed standards | High |
| **DQ02** | Documented active event has no observed Amplitude activity | High |
| **DQ03** | Duplicate Tracking ID | High |
| **DQ04** | Missing tracking owner | Medium |
| **DQ05** | Nonstandard event naming | Medium |
| **DQ06** | Missing required event property | High |
| **DQ07** | Deprecated event still firing | High |
| **DQ08** | Invalid service line | Medium |
| **DQ09** | Potential duplicate event firing within one second | Critical |
| **DQ10** | Future event timestamp | High |
| **DQ11** | Invalid device category | Medium |
| **DQ12** | Active internal tracking event not governed | High |

The rules allow tracking problems to be evaluated systematically rather than through manual inspection alone.

---

# SQL Architecture

The SQL implementation is divided into logical layers.

## Raw Layer

The raw layer preserves the original source data.

```text
raw.Amplitude_Events
raw.Internal_Tracking_Log
raw.Tracking_Event_Standards
raw.Website_Release_Log
```

---

## Staging Layer

The staging layer cleans and standardizes source values.

```text
staging.vw_AmplitudeEvents
staging.vw_InternalTrackingLog
staging.vw_TrackingStandards
staging.vw_WebsiteReleaseLog
```

Event aliases and inconsistent naming conventions are normalized so that events can be compared against canonical definitions.

---

## Governed Layer

The governed layer contains standardized event mappings and data-quality logic.

```text
governed.Event_Alias_Map
governed.vw_TrackingDQExceptions
```

This layer identifies records that violate the defined tracking and governance rules.

---

## Reporting Layer

Power BI consumes curated SQL reporting views rather than relying directly on raw event data.

```text
reporting.vw_EventCoverage
reporting.vw_DailyEventHealth
reporting.vw_ReleaseImpact
reporting.vw_DigitalJourneyDaily
reporting.vw_TrackingHealthScorecard
```

This separates source ingestion and validation logic from presentation-layer reporting.

---

# SQL Files

The SQL solution is provided both as modular scripts and as a consolidated script.

```text
sql/
│
├── 01_Create_Raw_Tables.sql
├── 02_Staging_and_Normalization.sql
├── 03_Data_Quality_Rules.sql
├── 04_PowerBI_Reporting_Views.sql
├── 05_Analysis_Queries.sql
└── Hospital_Amplitude_Tracking_Analytics_All.sql
```

### `01_Create_Raw_Tables.sql`

Creates the database schemas and raw source tables.

### `02_Staging_and_Normalization.sql`

Creates staging views and applies event-name normalization and alias mapping.

### `03_Data_Quality_Rules.sql`

Implements the automated data-quality exception framework.

### `04_PowerBI_Reporting_Views.sql`

Creates reporting-ready SQL views used by Power BI.

### `05_Analysis_Queries.sql`

Contains analytical and validation queries used to investigate the dataset.

### `Hospital_Amplitude_Tracking_Analytics_All.sql`

Provides a consolidated version of the SQL implementation for convenient review.

> The consolidated script and modular scripts represent alternative ways to review or execute the solution. They should not both be executed sequentially as separate implementations.

---

# Power BI Dashboard

The Power BI report contains **five analytical pages**, progressing from tracking validation to behavioral analysis.

---

## Page 1 — Tracking Health Overview

![Tracking Health Overview](images/01_tracking_health.png)

### Purpose

Provides an executive-level assessment of the overall health of the digital tracking environment.

The page answers:

> **Can we trust the tracking data?**

### Key Metrics

- Total Amplitude Events
- Total Data Quality Exceptions
- Critical Exceptions
- High Exceptions
- Specification Match %
- Events With Issues

Additional visuals show:

- Exceptions by DQ Rule
- Exceptions by Severity
- Event Coverage Status
- Most Affected Events

This provides stakeholders with an immediate indication of whether tracking problems require attention.

---

## Page 2 — Event Coverage Audit

![Event Coverage Audit](images/02_event_coverage.png)

### Purpose

Compares governed tracking expectations against actual observed event activity.

The page answers:

> **Are we tracking what we think we are tracking?**

Events are classified into statuses such as:

```text
Matched
Governed / Not Observed
Observed / Not Governed
Deprecated / Still Firing
```

### Key Metrics

- Total Governed Events
- Matched Events
- Governed Not Observed
- Observed Not Governed
- Deprecated Still Firing
- Coverage Match %

The detailed audit view allows analysts to identify gaps between documented specifications and actual digital instrumentation.

---

## Page 3 — Data Quality Exceptions

![Data Quality Exceptions](images/03_data_quality_exceptions.png)

### Purpose

Transforms automated data-quality validation into an actionable exception-management view.

### Key Metrics

- Total Exceptions
- Critical Exceptions
- High Exceptions
- Medium Exceptions
- Events Impacted
- Owners Impacted

The report can be filtered by:

- DQ Rule
- Severity
- Event
- Assigned Owner
- Date

The exception table provides the rule, affected event, issue type, severity, owner, timestamp, and issue description.

This page demonstrates that data quality is not simply about identifying bad records. Issues must also be **prioritized, assigned, investigated, and remediated**.

---

## Page 4 — Patient Digital Journey

![Patient Digital Journey](images/04_patient_digital_journey.png)

### Purpose

Once tracking quality has been evaluated, the project shifts from **data reliability** to **patient digital behavior**.

The patient journey is modeled as:

```text
Homepage
   ↓
Find Care
   ↓
Provider Search
   ↓
Provider Profile
   ↓
Schedule Click
   ↓
Scheduling Started
   ↓
Appointment Completed
```

### Analysis Includes

- Journey stage volume
- Stage-to-stage conversion
- Funnel drop-off
- Scheduling completion
- Scheduling abandonment
- Device performance
- Service-line performance
- Acquisition-channel performance
- Appointment completion trends

Users can segment the journey by:

- Date
- Device
- Service Line
- Acquisition Channel

This helps identify where patients encounter friction in the digital scheduling journey.

---

## Page 5 — Tracking Trend & Anomaly Monitoring

![Tracking Trend & Anomaly Monitoring](images/05_anomaly_monitoring.png)

### Purpose

Monitors event volume over time and identifies unusual changes that may indicate tracking failures.

Daily event activity is compared with a rolling **prior seven-day baseline**.

Events can receive health classifications such as:

```text
Normal
Warning Drop
Warning Spike
Critical Drop
Critical Spike
Insufficient History
```

### Key Metrics

The page includes metrics such as:

- Total Event Volume
- Prior 7-Day Average
- Event Variance
- Anomaly Count
- Critical Anomaly Count
- Events Monitored
- Largest Variance

---

# Release Impact Analysis

Website releases are incorporated into the anomaly analysis to help determine whether tracking changes coincide with deployments.

Two important measures are:

### Events 7D Pre

Number of times an event fired during the **seven days before a release**.

### Events 7D Post

Number of times the event fired during the **seven days after a release**.

The percentage change is calculated as:

```text
(Post-Release Events - Pre-Release Events)
------------------------------------------
           Pre-Release Events
```

This does not prove that a release caused an anomaly.

Instead, it provides evidence that analysts can use to prioritize investigation.

---

# Example Analytical Finding

One seeded scenario focuses on the `schedule_click` event.

Following a synthetic **August 18 scheduling JavaScript release**, mobile `schedule_click` volume declines substantially compared with its recent baseline.

Rather than immediately concluding that fewer patients wanted to schedule appointments, the analysis considers another possibility:

> **Did the release introduce a mobile-specific tracking regression?**

The anomaly is evaluated using:

- event volume;
- prior seven-day baseline;
- device segmentation;
- release timing; and
- pre-release versus post-release activity.

Because the decline aligns with a technical deployment and is concentrated within a specific tracking segment, the appropriate next step would be to investigate the instrumentation before treating the decline as a genuine change in patient behavior.

This illustrates one of the project's central analytical principles:

> **A change in reported behavior is not necessarily a change in actual behavior. Validate the instrumentation first.**

---

# Power BI DAX

The DAX measures used in the report are documented separately:

```text
documentation/PowerBI_DAX_Measures.txt
```

Measures include:

- tracking health KPIs;
- data-quality exception metrics;
- event coverage;
- journey-stage sessions;
- stage-to-stage conversion;
- scheduling completion;
- scheduling abandonment;
- anomaly counts;
- event-volume baselines; and
- release-impact calculations.

Measures were designed to return **0 rather than blank values** where appropriate to provide consistent KPI presentation.

---

# Dataset Validation

Dataset validation results are documented in:

```text
documentation/DATASET_VALIDATION.txt
```

Validation was performed before reporting to confirm that the synthetic datasets and seeded scenarios behaved as intended.

This reinforces a core principle used throughout the project:

> **Validate the source, date, definition, and quality of the data before interpreting the metric.**

---

# Repository Structure

```text
Hospital-Digital-Tracking-Analytics/
│
├── README.md
│
├── data/
│   ├── Amplitude_Events.csv
│   ├── Data_Quality_Rules.csv
│   ├── Internal_Tracking_Log.csv
│   ├── Tracking_Event_Standards.csv
│   └── Website_Release_Log.csv
│
├── sql/
│   ├── 01_Create_Raw_Tables.sql
│   ├── 02_Staging_and_Normalization.sql
│   ├── 03_Data_Quality_Rules.sql
│   ├── 04_PowerBI_Reporting_Views.sql
│   ├── 05_Analysis_Queries.sql
│   └── Hospital_Amplitude_Tracking_Analytics_All.sql
│
├── documentation/
│   ├── DATASET_VALIDATION.txt
│   └── PowerBI_DAX_Measures.txt
│
└── images/
    ├── 01_tracking_health.png
    ├── 02_event_coverage.png
    ├── 03_data_quality_exceptions.png
    ├── 04_patient_digital_journey.png
    └── 05_anomaly_monitoring.png
```

---

# How to Review the Project

For a quick review:

1. Read the **Project Overview** and **Business Problem** in this README.
2. Review the five Power BI dashboard screenshots.
3. Review `documentation/DATASET_VALIDATION.txt` for dataset validation.
4. Review `documentation/PowerBI_DAX_Measures.txt` for Power BI calculations.
5. Review the modular SQL scripts to follow the data pipeline from raw ingestion through reporting.

For the SQL implementation, the scripts are organized sequentially:

```text
01 → Raw Tables
02 → Staging & Normalization
03 → Data Quality
04 → Reporting Views
05 → Analysis
```

The consolidated SQL file is also available for reviewers who prefer to inspect the implementation in a single script.

---

# Skills Demonstrated

This project demonstrates practical experience with:

### Data Analytics
- Digital analytics
- Healthcare analytics
- Patient journey analysis
- Funnel analysis
- KPI development
- Trend analysis
- Root-cause analysis

### SQL & Data Engineering
- SQL Server
- T-SQL
- Layered data architecture
- Raw-to-staging transformations
- Data standardization
- Reporting views
- Analytical SQL

### Data Quality & Governance
- Data profiling
- Data validation
- Business definitions
- Canonical event standards
- Data-quality rules
- Exception management
- Ownership and stewardship
- Tracking governance
- Specification reconciliation

### Business Intelligence
- Power BI
- DAX
- KPI scorecards
- Interactive filtering
- Executive reporting
- Operational reporting
- Data storytelling

### Digital/Product Analytics Concepts
- Event-based analytics
- Amplitude-style event tracking
- Tracking specifications
- Event taxonomy
- Conversion funnels
- Digital journey analysis
- Instrumentation validation
- Release-aware anomaly monitoring

---

# Key Takeaway

The primary lesson demonstrated by this project is that a dashboard is only as reliable as the data and tracking implementation behind it.

Digital analytics should not begin with:

> **What does the dashboard say?**

It should begin with:

> **Can we trust what the dashboard is measuring?**

By combining tracking governance, SQL-based validation, automated data-quality rules, anomaly monitoring, release analysis, and Power BI reporting, this project creates a framework for moving from **raw digital events to trusted analytical insight**.

---

## Data Privacy

All data contained in this repository is **100% synthetic** and was generated specifically for this portfolio project.

No real patients, healthcare records, PHI, PII, proprietary organizational data, or production Amplitude data are included.
