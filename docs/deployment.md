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
(`DEPLOY_BUNDLES`) and capture the generated `BUNDLE_ID`. You must use SQL Developer or equivelant client to upload the zip file as BLOB to the database.

MANIFSET_JSON example:
``` json
{
  "app_id": 1200,
  "version": "v20260109_134227",
  "schema": "ORDS_PLSQL_GATEWAY",
  "created_at": "2026-01-09T13:42:30.742+00:00",
  "notes": "Credentials are not exported; ensure required credentials exist per environment."
}
```

---

### Step 3 — Deploy (scheduled job only)
Initial deployment is performed **via scheduler job**, not synchronously. 
- <b style="color: #ff7b72;">BUNDLE_ID</b> - is the chosen ID during upload in Step 2
- <b style="color: #ff7b72;">INITIAL</b> - for new installations
- <b style="color: #ff7b72;">YOUR_WORKSPACE</b> - APEX target workspace name
- <b style="color: #ff7b72;">APP_ID</b> - target APEX id (default is 1200)
- <b style="color: #ff7b72;">ALLOW_OVERWRITE</b> - If target APP_ID already exists in target APEX <b><u>Instance</u></b> it will overwrite it. <u>Make sure no application with the same ID exists on the same APEX instance</u>


```sql
DECLARE
  l_run_id  NUMBER;
  l_job     VARCHAR2(128);
BEGIN
  deploy_mgr_pkg.enqueue_deploy(
    p_bundle_id        => :bundle_id,
    p_install_mode     => 'INITIAL',
    p_workspace_name   => 'YOUR_WORKSPACE',
    p_app_id           => APP_ID,
    p_allow_overwrite  => 'N',
    o_run_id           => l_run_id,
    o_job_name         => l_job
  );
END;
/
```

---

### Step 4 — Monitor
Connect as the application schema owner and run the below queries:
- ```SELECT * FROM deploy_runs ORDER BY run_id DESC;```
- ```SELECT * FROM deploy_applied ORDER BY applied_at DESC;```

---

### Step 5 — Validate
After the job completes:
- open the APEX application
- verify core pages load
- verify chatbot initializes
- verify required `APP_CONFIG` entries exist

---

### Step 6 — Enable jobs
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

These topics are documented separately in [Update Guide](update.md).

**See also**
- [Update Guide](update.md)
- [Admin Guide](admin-guide.md)
- [Deployment Manager API](deploy-manager-api.md)
- [Troubleshooting](troubleshooting.md)
