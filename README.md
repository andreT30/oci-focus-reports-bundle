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

## Alignment with FOCUS FinOps Standard

This application is designed to support organizations following the **FOCUS FinOps Framework** — a widely adopted set of principles and practices for financial accountability in cloud environments maintained by the FinOps Foundation (see https://focus.finops.org/).

The FOCUS FinOps Standard defines four key use cases for cost and usage analytics:

- **Find**: Discover and understand cloud spend and usage
- **Organize**: Structure cost data by business entities like teams, workloads, and projects
- **Compute**: Analyze and quantify cost drivers and metrics
- **Optimize**: Plan, recommend, and implement efficiency actions

This platform provides dashboards, reports, and tooling that directly support these use cases, and is designed to help practitioners move along the FinOps maturity curve using both curated analytics and natural-language exploration.

### FOCUS FinOps Standard Framework

<p align="center">
  <img
    src="https://focus.finops.org/wp-content/uploads/2025/12/BG-Image-v3.png"
    alt="FOCUS FinOps Framework"
    width="600"
  />
</p>

*Source: https://focus.finops.org/*

---

## High-level architecture

The application follows a **database-first, three-layer architecture**:

- **Presentation**: Oracle APEX (dashboards, reports, chatbot UI)
- **Logic**: PL/SQL packages (analytics, chatbot, deployment manager)
- **Data**: OCI cost usage, resources, relationships, configuration

See the full architecture and diagrams in [Architecture](docs/architecture.md).

---

## How users interact with the app

Typical flow:
1. Start at the **Home dashboard** for an overview
2. Drill down via **Workloads**, **Cost Report**, or **Usage Report**
3. Use the **AI chatbot** when you don’t know where to start
4. Explore resources and tags via **Resource Explorer**

Detailed walkthrough:  [User Guide](docs/usage-guide.md) 

---

## Documentation


> **New here? Start with…**
>
> - 👤 **End users** → [User Guide](docs/usage-guide.md)  
>   Learn how to use dashboards, reports, and the AI chatbot.
> - 🛠 **Admins / Operators** → [Admin & Operations Guide](docs/admin-guide.md)  
>   Learn configuration, job control, and day-to-day operations.
> - 🧱 **Architects / Reviewers** → [Architecture](docs/architecture.md) + [Security Model](docs/security.md)  
>   Understand system design, data flow, and trust boundaries.
>

### Getting started
- [User Guide](docs/usage-guide.md)  
  How to use dashboards, reports, and the chatbot.
- [APEX Pages Map](docs/apex-pages.md)  
  Page-by-page map of the application UI.

### Architecture & design
- [Architecture](docs/architecture.md)  
  System components, data flow, and diagrams.
- [Data Model](docs/data-model.md)  
  Core tables, relationships, and analytical model.
- [Configuration](docs/configuration.md)  
  `APP_CONFIG` keys and runtime behavior.
- [Security Model](docs/security.md)  
  Authentication, authorization, and trust boundaries.

### Operations
- [Deployment Guide](docs/deployment.md)  
  **Initial installation only** (Deployment Manager).
- [Update Guide](docs/update.md)  
  In-app updates and dry-run behavior.
- [Admin & Operations Guide](docs/admin-guide.md)  
  Day-to-day administration and job control.
- [Troubleshooting](docs/troubleshooting.md)  
  Common issues and diagnostics.

### Internals
- [NL2SQL Chatbot](docs/chatbot.md)  
  Chatbot pipeline, glossary, and execution model.
- [Deployment Manager API](docs/deploy-manager-api.md)  
  Supported export/import APIs.

## Deployment vs Updates (important)

This project **explicitly separates** initial deployment from application updates.

### Initial deployment
- Performed **once per environment**
- Executed via a **Deployment Manager PL/SQL package**
- Consumes the **bundle ZIP as a ZIP (BLOB)** — no extraction
- Uses a **scheduler job** for deployment

See:  [Deployment Guide](docs/deployment.md) 

### Application updates
- Performed **inside the application UI**
- No SQL scripts or manual redeployments
- Supports dry-run mode
- Fully logged and auditable

See:  [Update Guide](docs/update.md)

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

Details:  [Admin & Operations Guide](docs/admin-guide.md) 

---

## Configuration model

All runtime behavior is driven by configuration tables (primarily `APP_CONFIG`):

- no hardcoded OCIDs
- no hardcoded tag keys
- no environment-specific logic in code

See:  [Configuration](docs/configuration.md)

---

## Administration & operations

Administrators can:
- manage workloads and subscriptions
- control scheduler jobs
- manage chatbot glossary and metadata
- monitor runs, logs, and data freshness

Administrators **do not deploy or update** the application via SQL.

See:  [Admin & Operations Guide](docs/admin-guide.md) 

---

## Security & trust

- Authentication via Oracle APEX / IAM
- Role-based authorization
- No OCI credentials or secrets in GitHub
- Deterministic SQL generation (no injection risk)
- Full audit trail for deployments, updates, jobs, and chatbot execution

See:  [Security Model](docs/security.md)  

---

## Repository structure

```
bundle_app1200.zip         # The zip that contains all the application assets

db/
  ov_run_as_admin.sql      # SQL script to run as ADMIN
  deploy_manager_ddl.sql   # Deploy manager script to create DB objects, run as db application owner
  deploy_manager_pkg.sql   # Deploy manager package, run as db application owner

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
