# OCI Cost Analytics & NL2SQL Chatbot (Oracle APEX)

## Overview
This repository contains an Oracle APEX application and its supporting database objects for **OCI cost analysis, reporting, and analytics**, including an **AI-powered NL2SQL chatbot** for natural-language querying of cost and resource data.

The application is production-grade and designed to run on **Oracle Autonomous Database (ADB)** with **Oracle APEX**, integrating OCI cost usage data, resource metadata, tagging, and analytics dashboards.

## Key Capabilities
- OCI cost usage analytics (daily, monthly, trend, variance)
- Resource-level cost attribution and relationships
- Tag-based filtering and normalization
- Interactive dashboards and reports in Oracle APEX
- NL2SQL chatbot for natural-language questions (cost, usage, workloads)
- Configurable via database-driven parameters (no hardcoded environment values)
- Background jobs for refresh and aggregation

## High-Level Architecture
The system is composed of:
- **APEX Application (UI layer)**  
  Dashboards, reports, admin pages, and chatbot UI.
- **Database Layer (logic & data)**  
  Tables, views, PL/SQL packages, jobs, and configuration.
- **OCI Integration Layer**  
  Cost & usage ingestion, resource metadata, tagging conventions.

See [docs/architecture.md](docs/architecture.md) for details.

## Repository Structure
apex/
f1200.sql # Oracle APEX application export (App 1200)

db/
ddl/ # Tables, views, packages, jobs, indexes
migrations/ # Bundle migration metadata

docs/
architecture.md
data-model.md
configuration.md
chatbot.md
deployment.md
troubleshooting.md


## Deployment (Summary)
1. Deploy database objects (`db/ddl`)
2. Seed configuration and chatbot metadata
3. Import the APEX application
4. Configure environment-specific settings (APP_CONFIG)
5. Enable background jobs

Detailed steps: [docs/deployment.md](docs/deployment.md)

## Configuration
The application is configured entirely through database tables (primarily `APP_CONFIG`).
No secrets are stored in GitHub.

See [docs/configuration.md](docs/configuration.md).

## Target Audience
- OCI / FinOps engineers
- Oracle APEX developers
- Cloud cost analysts
- Platform operators
- Architects evaluating OCI cost tooling

## License
Internal / project-specific. Review before external distribution.
