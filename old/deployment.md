# Deployment

Home: [README](../README.md) · **Docs** · **Deployment**

## Overview

This application is deployed using a **database-resident Deployment Manager**
implemented in PL/SQL (`DEPLOY_MGR_PKG`).

The Deployment Manager consumes the **application bundle ZIP as a ZIP (stored as a BLOB)** and applies
its contents directly—**no manual extraction is required or expected**.

This document covers **initial deployment only**.
Application updates are handled **inside the application itself** and are documented separately.

---

## Deployment Components

### 1. Admin prerequisite script (mandatory)
**File:** `ov_run_as_admin.sql`  
**Executed as:** Autonomous Database ADMIN (or equivalent privileged user)

Purpose:
- grant required system and object privileges
- enable scheduler, APEX import, and DBMS package access

This script must be executed **before the first deployment** in each environment.

---

### 2. Deployment Manager installation (application schema)

The Deployment Manager is installed in the **application schema** using:

- `deploy_manager_ddl.sql`
- `deploy_manager_pkg.sql`

Run as the application schema owner:

@deploy_manager_ddl.sql  
@deploy_manager_pkg.sql

These scripts create:
- bundle storage tables (ZIP stored as BLOB)
- deployment run and log tables
- the `DEPLOY_MGR_PKG` API

---

## Bundle ZIP

The bundle ZIP is the **single deployment artifact**.

Typical contents:
- `db/ddl/*.sql` — database objects (tables, views, packages, procedures)
- `db/ddl/90_jobs.sql` — scheduler jobs created as part of the application
- `apex/f1200.sql` — Oracle APEX application export
- `manifest.json` — bundle metadata

The Deployment Manager reads and processes these entries **directly from the ZIP**.

---

## Deployment Procedure (Target ADB)

### Step 0 — Run admin script
Connect as ADMIN and run:

@ov_run_as_admin.sql

---

### Step 1 — Install Deployment Manager
Connect as the application schema owner and run:

@deploy_manager_ddl.sql  
@deploy_manager_pkg.sql

---

### Step 2 — Insert bundle ZIP
Insert the bundle ZIP into the Deployment Manager bundle table
(e.g. `DEPLOY_BUNDLES`) and capture the generated `BUNDLE_ID`.

---

### Step 3 — Deploy (scheduled job only)
Initial deployment is performed **via scheduler job**, not synchronously.

```sql
DECLARE
  l_run_id   NUMBER;
  l_job_name VARCHAR2(128);
BEGIN
  deploy_mgr_pkg.enqueue_deploy(
    p_bundle_id         => :BUNDLE_ID,
    p_enable_jobs_after => FALSE,
    p_dry_run           => FALSE,
    o_run_id            => l_run_id,
    o_job_name          => l_job_name
  );

  DBMS_OUTPUT.PUT_LINE('RUN_ID='||l_run_id||' JOB='||l_job_name);
END;
/
```

---

### Step 4 — Validate
After the job completes:
- open the APEX application
- verify core pages load
- verify chatbot initializes
- verify required `APP_CONFIG` entries exist

---

### Step 5 — Enable jobs
Jobs defined in `db/ddl/90_jobs.sql` are created **disabled**.

Enable them only after:
- configuration is verified
- initial validation is complete

---

## Logging & Observability

Each deployment is tracked via deployment run tables:
- run id
- status
- timestamps
- detailed execution log (CLOB)

Deployment issues should always be investigated via these logs.

---

## What this document does NOT cover

- Application updates
- In-app self-update flows
- Dry-run update behavior
- Bundle export

These topics are documented separately in `docs/update.md`.

**See also**
- [Update Guide](update.md)
- [Admin Guide](admin-guide.md)
- [Deployment Manager API](deploy-manager-api.md)
- [Troubleshooting](troubleshooting.md)
