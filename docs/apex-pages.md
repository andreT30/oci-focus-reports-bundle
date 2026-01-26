# APEX Pages Map

Home: [README](../README.md) · **Docs** · **APEX Pages Map**

This page maps Oracle APEX pages to functional areas so operators and contributors can quickly find:
- where a feature lives in the UI
- which pages are user-facing vs admin-only
- which pages relate to deployment, configuration, jobs, and chatbot rules

If you are a first-time user, start with the [User Guide](usage-guide.md).

---

## How to read this page map

- **Core user pages** are the main dashboards, reports, and the chatbot.
- **Admin / maintenance pages** are for configuration, data loading, monitoring, and APEX built-in admin utilities.
- For each page you get:
  - **What it’s for**
  - **Key UI regions** (major page regions)
  - **Server-side processes** (AJAX/on-demand processes and main actions)

---

## Core user pages

| Page | Name | Alias | Purpose | Primary doc |
|---:|---|---|---|---|
| 1 | Home | HOME | Landing dashboard: subscriptions, credits, workload summaries & trends | docs/usage-guide.md#home |
| 2 | OVBot | OVBOT | NL2SQL chatbot UI (chat, dataset/model selection, results dialog) | docs/chatbot.md |
| 3 | Workloads | WORKLOADS | Workload-centric analytics, trends, drilldowns | docs/usage-guide.md#workloads |
| 4 | Usage Report | USAGE-REPORT | Usage-focused reporting (filters → usage views) | docs/usage-guide.md#usage-report |
| 5 | Cost Report | COST-REPORT | Cost-focused reporting (filters → cost views) | docs/usage-guide.md#cost-report |
| 6 | Resource Explorer | RESOURCE-EXPLORER | Resource inventory + attributes + filtering | docs/usage-guide.md#resource-explorer |
| 7 | My Reports | MY-REPORTS | Saved/custom reports area | docs/usage-guide.md#my-reports |
| 8 | OCI Calculator | OCI-CALCULATOR | Calculator utilities for OCI-related calculations | docs/usage-guide.md#oci-calculator |
| 300 | Availability Metrics | AVAILABILITYMETRICS | Availability KPIs/metrics view | docs/usage-guide.md#availability-metrics |

---

## Chatbot & glossary administration (power users)

| Page | Name | Alias | Purpose | Primary doc |
|---:|---|---|---|---|
| 30 | NL2SQL Bot Debug | NL2SQL-BOT-DEBUG | Debug UI for NL2SQL pipeline and generated SQL | docs/chatbot.md#debugging |
| 31 | Chatbot Parameters | CHATBOT-PARAMETERS | Parameter management for chatbot behavior | docs/chatbot.md#configuration |
| 32 | UpdateChatBotParams | UPDATECHATBOTPARAMS | Edit/update chatbot parameters | docs/chatbot.md#configuration |
| 33 | NL2SQL Table Definition Tool | NL2SQL-TABLE-DEFINITION-TOOL1 | Tooling to define/maintain NL2SQL schema metadata | docs/chatbot.md#schema-metadata |
| 34 | UpdateSummaries | UPDATESUMMARIES | Maintain summaries used by chatbot/reporting | docs/chatbot.md#summaries |
| 35 | UpdateBusinessGlossary | UPDATEBUSINESSGLOSSARY | Edit business glossary rules/keywords | docs/chatbot.md#business-glossary |
| 36 | CreateBusinessGlossary | CREATEBUSINESSGLOSSARY | Create new glossary entries | docs/chatbot.md#business-glossary |

---

## Configuration, data loading, and operational tooling (admins)

| Page | Name | Alias | Purpose | Primary doc |
|---:|---|---|---|---|
| 501 | Application Tables | APP-DETAILS | Admin view into core application tables | docs/admin-guide.md#application-tables |
| 502 | Create Subscription Detail | CREATE-SUBSCRIPTION-DETAIL | Manage subscription detail records | docs/admin-guide.md#subscriptions |
| 503 | Create Workload | CREATE-WORKLOAD | Create workloads (metadata/config used in analytics) | docs/admin-guide.md#workloads-admin |
| 504 | UpdateMyReports | UPDATEMYREPORTS | Admin/maintenance for saved reports | docs/admin-guide.md#my-reports-admin |
| 505 | My Reports & Workloads | MY-REPORTS-WORKLOADS | Mapping reports to workloads / combined admin view | docs/admin-guide.md#my-reports-workloads |
| 506 | Data Load | DATA-LOAD | Data load operations (staging/import) | docs/admin-guide.md#data-load |
| 508 | Initial Load | INITIAL-LOAD | First-time initialization and baseline ingestion | docs/admin-guide.md#initial-load |
| 507 | Edit Scheduler Job | EDIT-SCHEDULER-JOB | Edit/inspect scheduler job definitions | docs/admin-guide.md#scheduler-jobs |

---

## App shell / authentication / theme

| Page | Name | Alias | Purpose | Primary doc |
|---:|---|---|---|---|
| 0 | Global Page | — | Shared regions/items for all pages (header, JS/CSS hooks, shared UI) | docs/architecture.md#presentation-layer-oracle-apex |
| 9999 | Login Page | LOGIN | Authentication entry point | docs/security.md#authentication |
| 1004 | Theme Switch | THEME-SWITCH | Theme switching support | docs/usage-guide.md#themes |

---

## Built-in / system administration pages (APEX utilities)

These are standard APEX productivity/admin pages included with the app.

| Page | Name | Alias | Purpose |
|---:|---|---|---|
| 10000 | Administration | ADMINISTRATION | Admin landing |
| 10010 | Email Reporting | EMAIL-REPORTING | Email reporting utilities |
| 10030 | About this Application | ABOUT-THIS-APPLICATION | App info/about |
| 10040 | Activity Dashboard | ACTIVITY-DASHBOARD | Usage/activity metrics |
| 10041 | Top Users | TOP-USERS | Top users analytics |
| 10042 | Application Error Log | APPLICATION-ERROR-LOG | Error log viewer |
| 10043 | Page Performance | PAGE-PERFORMANCE | Performance analytics |
| 10044 | Page Views | PAGE-VIEWS | Page view analytics |
| 10045 | Automations Log | AUTOMATIONS-LOG | Automations log |
| 10046 | Log Messages | LOG-MESSAGES | Application log messages |
| 10050 | Configuration Options | CONFIGURATION-OPTIONS | APEX configuration options |
| 10060 | Feedback | FEEDBACK | Feedback entry |
| 10061 | Feedback Submitted | FEEDBACK-SUBMITTED | Feedback confirmation |
| 10063 | Manage Feedback | MANAGE-FEEDBACK | Feedback admin |
| 10064 | Feedback | FEEDBACK1 | Additional feedback page |
| 10070 | Theme Style Selection | THEME-STYLE-SELECTION | Theme style selection |
| 10080 | App Export | APP-EXPORT | Export utilities |
| 10081 | App Import | APP-IMPORT | Import utilities |
| 10082 | App Bundle Logs | APP-IMPORT-LOGS | Bundle import logs |
| 10083 | Download App | DOWNLOAD-APP | Download utilities |

---

# Per-page details (from export)

Below is the extracted detail for the most important pages. (Regions are the major page regions; processes are key server-side actions.)

## Page 1 — Home (HOME)

**What it’s for**
- Primary landing dashboard: subscription overview, credits, projections, workload costs, monthly/weekly trends.

**Key UI regions**
- Focus Cost Reporting
- Region Selector
- Subscriptions
- Subscription Data (No-PAYG)
- Credit Summary
- Projection Filters
- Subscription Data (PAYG)
- Credit Consumption (PAYG)
- Credit Consumption Chart (PAYG)
- Workload Costs
- Workload Monthly
- Workload 8 weeks
- Consolidated Workload Costs
- Consolidated Cost Per Workload Monthly

**Key server-side processes (AJAX/on-demand)**
- Update Credit Summary Cards
- Update Credit Summary Cards 30 days
- GET_WRKLD_COSTS_MONTHLY
- GET_WRKLD_COSTS_BY_RN
- GET_WRKLD_WORKLOADS_LIST
- GET_WRKLD_WEEKLY_BY_RN

---

## Page 2 — OVBot (OVBOT)

**What it’s for**
- Chat interface for NL2SQL: manage conversations, select dataset/model, run NL question → SQL → results.

**Key UI regions**
- Conversation Management
- Select Chat
- ChatBot
- Chat Input Bar
- Select Dataset
- DataReportDialog

**Key server-side processes**
- Init Chat ID
- RUN_AI_PROCESS
- RESET_AI_STATE
- SET_OR_CLEAR_P2_SQL
- SAVE_CHAT_TITLE

---

## Page 3 — Workloads (WORKLOADS)

**What it’s for**
- Workload-based cost analytics with interactive charts and drill-downs.

**Key UI regions** (high-level)
- (Extracted regions exist; expanded functional walkthrough is in docs/usage-guide.md#workloads)

**Key server-side processes**
- (On-demand processes present; documented in the workload guide section)

---

## Page 4 — Usage Report (USAGE-REPORT)

**What it’s for**
- Usage-centric reporting with filterable dimensions and time ranges.

---

## Page 5 — Cost Report (COST-REPORT)

**What it’s for**
- Cost-centric reporting with filterable dimensions and time ranges.

---

## Page 6 — Resource Explorer (RESOURCE-EXPLORER)

**What it’s for**
- Browse/search resources, attributes, and tags; supports discovery and drilldowns.

---

## Page 7 — My Reports (MY-REPORTS)

**What it’s for**
- Access saved reports and report sets.

---

## Page 8 — OCI Calculator (OCI-CALCULATOR)

**What it’s for**
- Calculator-style utilities supporting OCI cost analysis workflows.

---

## Page 30 — NL2SQL Bot Debug (NL2SQL-BOT-DEBUG)

**What it’s for**
- Debugging and transparency for NL2SQL: inspect generated SQL, pipeline decisions, and logs.

---

## Pages 31–36 — Chatbot metadata management

**What it’s for**
- Manage chatbot parameters, glossary rules/keywords, summaries, and schema metadata.

---

## Admin pages 501–508

**What it’s for**
- Manage workloads/subscriptions/reports, data loading, job editing, and initial setup operations.

---

**See also**
- [Usage Guide](usage-guide.md)
- [Admin Guide](admin-guide.md)
