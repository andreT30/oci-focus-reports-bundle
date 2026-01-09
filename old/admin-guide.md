# Administration & Operations Guide

Home: [README](../README.md) · **Docs** · **Administration & Operations**

This guide is for **application administrators and operators**.
It covers configuration, monitoring, and operational control **after initial deployment**.

> Initial installation is documented in `docs/deployment.md`.  
> Application updates are handled **inside the application UI** and documented in `docs/update.md`.

---

## Administrator Responsibilities

Administrators are responsible for:

- validating post-deployment configuration
- managing workloads and subscriptions
- controlling scheduler jobs
- maintaining chatbot metadata
- monitoring runs, logs, and data freshness

Administrators **do not** deploy or update the application manually via SQL.

---

## Access Control

Administrative capabilities are protected using:

- Oracle APEX authorization schemes
- application-level roles

Only authorized users can access:
- configuration pages
- workload and subscription management
- job control
- chatbot metadata editors
- update workflows

---

## Configuration Management

### Central Configuration Table
- `APP_CONFIG`

All runtime behavior is driven from configuration values:
- OCI scope (compartments, regions)
- tagging conventions
- feature toggles
- chatbot behavior

Best practices:
- treat configuration as code
- document every change
- validate after each change

---

## Workload Administration

### Purpose
Workloads define logical groupings used by:
- dashboards
- reports
- cost attribution
- chatbot queries

### Admin Pages
- **Create Workload**
- **My Reports & Workloads**

### Best Practices
- avoid overlapping workload definitions
- keep naming consistent
- validate workloads against real resources

Incorrect workload definitions lead to misleading analytics.

---

## Subscription Management

### Purpose
Manage OCI subscription metadata used by:
- credit tracking
- projections
- executive dashboards

### Admin Pages
- **Create Subscription Detail**

Changes here directly affect financial reporting.

---

## Scheduler Jobs

### Source of Jobs
All application scheduler jobs are defined in the bundle under:

```
db/ddl/90_jobs.sql
```

During initial deployment:
- jobs are created **disabled**
- no jobs are enabled automatically

---

### Job Lifecycle

Administrators control job lifecycle entirely from the application:

1. Review job definitions
2. Enable jobs after configuration validation
3. Monitor execution and duration
4. Disable jobs during maintenance or incidents

Jobs should **never** be enabled before configuration is complete.

---

### Job Monitoring
Use admin pages and logs to:
- verify successful execution
- identify failures
- observe execution time trends

---

## Data Load & Initialization

### Initial Load
Performed once after deployment to bootstrap data.

### Data Load
Used for controlled reprocessing or corrections.

These operations are exposed via the admin UI and logged.

---

## Chatbot Administration

### What Admins Control
- business glossary rules
- keywords and synonyms
- dataset metadata
- summaries used in responses

### Admin Pages
- Business Glossary editors
- Chatbot parameter pages
- Debug and inspection pages

---

### Extending Chatbot Coverage
To support new business language:
1. Add or update glossary rules
2. Add keywords/synonyms
3. Test via chatbot UI
4. Monitor logs

No deployment or update is required.

---

## Application Updates

Application updates are **not performed via SQL scripts**.

Updates are:
- triggered from the application UI
- executed using the internal Deployment Manager
- logged and auditable

See: `docs/update.md`

---

## Monitoring & Logging

### What Is Logged
- job executions
- data load runs
- chatbot requests
- deployment/update runs
- errors and warnings

### Operator Guidance
- always capture run IDs
- use logs as the primary troubleshooting source
- never modify data directly to fix issues

---

## Operational Checklists

### After Initial Deployment
- [ ] configuration completed (`APP_CONFIG`)
- [ ] initial data load executed
- [ ] dashboards render correctly
- [ ] chatbot initializes
- [ ] jobs reviewed but still disabled

---

### Before Enabling Jobs
- [ ] configuration validated
- [ ] data load successful
- [ ] admin access verified
- [ ] monitoring in place

---

## Common Admin Mistakes

- enabling jobs too early
- modifying data outside the app
- overlapping workload definitions
- changing tag keys without validation
- attempting updates via SQL

---

## Governance & Audit

- all operations are logged
- chatbot SQL is traceable
- configuration changes are auditable
- deployment and updates are separated

This separation is intentional and reduces operational risk.

**See also**
- [Deployment Guide](deployment.md)
- [Update Guide](update.md)
- [Configuration Reference](configuration.md)
- [Troubleshooting](troubleshooting.md)
- [Security Model](security.md)
