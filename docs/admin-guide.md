# Administration & Operations Guide

This guide is for:
- application administrators
- platform owners
- FinOps / cloud operations leads
- power users managing configuration and data

It explains how to **operate, configure, and extend** the application safely.

---

## Admin Responsibilities

Administrators are responsible for:
- configuring environments
- managing workloads and subscriptions
- maintaining chatbot metadata
- monitoring jobs and data freshness
- troubleshooting issues

No code changes are required for normal administration.

---

## Access Control

Administrative pages are protected via:
- APEX authorization schemes
- application roles

Only authorized users should have access to:
- configuration pages
- data load operations
- chatbot metadata editors

---

## Workload Administration

### Pages
- **Create Workload**
- **My Reports & Workloads**

### Purpose
Workloads define logical groupings used across:
- dashboards
- reports
- chatbot queries

---

### Best Practices
- keep workload definitions stable
- avoid overlapping definitions
- document naming conventions
- validate workloads against real resources

Misconfigured workloads lead to misleading analytics.

---

## Subscription Management

### Pages
- **Create Subscription Detail**

### Purpose
Manage OCI subscription metadata:
- PAYG vs non-PAYG
- credit pools
- subscription boundaries

This impacts:
- projections
- credit depletion views
- executive reporting

---

## Data Load & Initialization

### Pages
- **Initial Load**
- **Data Load**

### Initial Load
Used once per environment to:
- bootstrap data
- initialize baseline metadata

---

### Data Load
Used for:
- reprocessing
- manual refresh
- controlled ingestion

---

### Best Practices
- run Initial Load only once
- use Data Load for corrections
- verify logs after every run

---

## Scheduler Jobs

### Pages
- **Edit Scheduler Job**

### Purpose
View and control background jobs that:
- refresh cost data
- aggregate time series
- sync resource metadata

---

### Operational Guidance
- jobs should run during off-peak hours
- never enable jobs before configuration is complete
- monitor job duration trends

---

## Chatbot Administration

### Pages
- Chatbot Parameters
- Update ChatBotParams
- NL2SQL Table Definition Tool
- Update Summaries
- Update Business Glossary
- Create Business Glossary

---

### What Admins Control
- glossary rules
- keywords and synonyms
- dataset definitions
- summaries
- routing behavior

---

### Extending Chatbot Coverage

To support new business language:
1. Create glossary rule
2. Add keywords/synonyms
3. Test via chatbot UI
4. Monitor logs

No PL/SQL changes required in most cases.

---

## Configuration Management

### Central Table
- `APP_CONFIG`

### Rules
- keys are stable
- values vary by environment
- secrets are external

---

### Change Management
- update config via admin UI or SQL
- test impact in lower environments
- log and document changes

---

## Monitoring & Logging

### What is Logged
- job execution
- chatbot requests
- SQL generation
- errors and warnings

---

### How to Monitor
- use built-in admin pages
- query logging tables
- correlate via run/request IDs

---

## Troubleshooting Workflow

1. Identify issue
2. Capture run/request ID
3. Inspect logs
4. Validate configuration
5. Adjust workload/glossary/config
6. Re-test

---

## Operational Checklists

### After Deployment
- [ ] APEX app loads
- [ ] Config keys populated
- [ ] Jobs disabled
- [ ] Initial load completed
- [ ] Jobs enabled
- [ ] Dashboards populated
- [ ] Chatbot answers basic questions

---

### After Configuration Changes
- [ ] Validate dashboards
- [ ] Validate chatbot
- [ ] Check job logs

---

## Governance & Audit

- All actions are logged
- Chatbot SQL is traceable
- Cost attribution logic is transparent

This supports:
- audits
- cost governance
- compliance reviews

---

## Common Admin Mistakes

- enabling jobs too early
- changing tag keys without validation
- overlapping workload definitions
- ignoring chatbot logs

---

## Final Notes

Treat configuration as **code**:
- document changes
- review before applying
- test in non-prod environments

This application rewards discipline with clarity.
