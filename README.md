# OCI Cost Analytics & NL2SQL Chatbot
**Oracle APEX • Oracle Autonomous Database • OCI FinOps**

---

## What this is

This repository contains a **production-grade Oracle APEX application** for **OCI cost analytics, reporting, and governance**, including an **explainable NL2SQL AI chatbot** that allows users to query cost and usage data using natural language.

The application is designed to be:
- accurate and auditable
- configuration-driven
- secure by design
- usable by both technical and non-technical users

It runs on **Oracle Autonomous Database (ADB)** with **Oracle APEX**, and integrates OCI Cost & Usage data, OCI resource metadata, and tagging.

---

## Who this is for

- **FinOps / Finance teams** – cost visibility, trends, credits, chargeback
- **Engineering & Operations** – workload, service, and resource analytics
- **Platform owners & Architects** – OCI governance and accountability
- **Executives & Stakeholders** – high-level insights without technical complexity

No SQL or Oracle expertise is required for end users.

---

## Key capabilities

### Cost & Usage Analytics
- Daily and monthly cost analysis
- Workload-level and resource-level attribution
- Trend analysis (MoM, QoQ, projections)
- PAYG and non-PAYG credit tracking

### Dashboards & Reports
- Executive overview dashboards
- Flexible cost and usage reports
- Drill-down from high level → workload → resource
- Saved and reusable reports

### OCI Resource Visibility
- Resource inventory across compartments and regions
- Parent–child resource relationships
- Tag-based attribution and filtering

### NL2SQL AI Chatbot
- Ask questions in natural language (e.g. “cost last month by service”)
- Deterministic, metadata-driven SQL generation
- Fully logged and explainable
- Safe execution with guardrails

### Enterprise-Ready Design
- Database-centric logic
- Configuration over hardcoding
- No secrets in source control
- Full auditability

---

## High-level architecture

The application follows a **database-first, three-layer architecture**:

- **Presentation**: Oracle APEX (dashboards, reports, chatbot UI)
- **Logic**: PL/SQL packages (analytics, chatbot, deployment manager)
- **Data**: OCI cost usage, resources, relationships, configuration

See the full architecture and diagrams in  
`docs/architecture.md`.

---

## How users interact with the app

Typical flow:
1. Start at the **Home dashboard** for an overview
2. Drill down via **Workloads**, **Cost Report**, or **Usage Report**
3. Use the **AI chatbot** when you don’t know where to start
4. Explore resources and tags via **Resource Explorer**

Detailed walkthrough:  
`docs/usage-guide.md`

---

## Deployment vs Updates (important)

This project **explicitly separates** initial deployment from application updates.

### Initial deployment
- Performed **once per environment**
- Executed via a **Deployment Manager PL/SQL package**
- Consumes the **bundle ZIP as a ZIP (BLOB)** — no extraction
- Uses a **scheduler job** for deployment

See:  
`docs/deployment.md`

### Application updates
- Performed **inside the application UI**
- No SQL scripts or manual redeployments
- Supports dry-run mode
- Fully logged and auditable

See:  
`docs/update.md`

---

## Scheduler jobs

All application scheduler jobs are defined in:

```
db/ddl/90_jobs.sql
```

Behavior:
- Jobs are created **disabled** during deployment
- Administrators enable them only after configuration validation
- Job lifecycle is controlled via the application admin UI

Details:  
`docs/admin-guide.md`

---

## Configuration model

All runtime behavior is driven by configuration tables (primarily `APP_CONFIG`):

- no hardcoded OCIDs
- no hardcoded tag keys
- no environment-specific logic in code

See:  
`docs/configuration.md`

---

## Administration & operations

Administrators can:
- manage workloads and subscriptions
- control scheduler jobs
- manage chatbot glossary and metadata
- monitor runs, logs, and data freshness

Administrators **do not deploy or update** the application via SQL.

See:  
`docs/admin-guide.md`

---

## Security & trust

- Authentication via Oracle APEX / IAM
- Role-based authorization
- No OCI credentials or secrets in GitHub
- Deterministic SQL generation (no injection risk)
- Full audit trail for deployments, updates, jobs, and chatbot execution

See:  
`docs/security.md`

---

## Repository structure

```
apex/
  f1200.sql                # Oracle APEX application export

db/
  ddl/                     # Tables, views, packages, jobs
  migrations/              # Bundle migration metadata

docs/
  architecture.md
  apex-pages.md
  usage-guide.md
  admin-guide.md
  chatbot.md
  configuration.md
  data-model.md
  deployment.md
  update.md
  troubleshooting.md
  security.md
  deploy-manager-api.md
  diagrams/
```

---

## Why this application stands out

- **Explainable analytics** (no hidden logic)
- **Explainable AI** (NL2SQL with full traceability)
- **Clear operational boundaries** (deploy vs update)
- **Designed for real FinOps workflows**, not demos

---

## Status

This repository contains:
- production APEX application export
- full database schema and logic
- a documented deployment manager
- complete end-user, admin, and security documentation

It is ready for:
- onboarding new users
- audits and reviews
- long-term maintenance
- Git-based collaboration

---

**Documentation is part of the product.**
