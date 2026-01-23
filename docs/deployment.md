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

### Step 2 — Upload bundle ZIP

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

#### - SQL Developer 
Insert the bundle ZIP into the Deployment Manager bundle table
(`DEPLOY_BUNDLES`) and capture the generated `BUNDLE_ID`.

#### - SQLcl (either installed locally or as part of SQL Developer in VSCode)
Create the below script locally:
```sql
INSERT INTO deploy_bundles (
    app_id,
    version_tag,
    manifest_json,
    bundle_zip,
    sha256
)
VALUES (
    :app_id,
    :version_tag,
    :manifest_json,
    EMPTY_BLOB(),
    :sha256
)
RETURNING bundle_zip INTO :blob;
```

Launch SQLcl inside the same directory as the script above .
Version Tag, check github version update.
Manifest JSON, check example above and update accordingly.

Sample execution:
```sql
sql demo_user/demo_pwd@db_high <<EOF
VAR blob BLOB
EXEC :app_id := 1200
EXEC :version_tag := 'v20260109_134227'
EXEC :manifest_json := '{"app":"focus-reports","version":"v20260109_134227"}'

@insert_bundle.sql
LOAD BLOB :blob FROM FILE 'bundle_app1200.zip'
COMMIT
EOF
```


---

### Step 3 — Deploy (scheduled job only)
Initial deployment is performed **via scheduler job**, not synchronously. 
- $\color{#ff7b72}{\textsf{BUNDLE ID}}$ - Is the chosen ID during upload in Step 2
- $\color{#ff7b72}{\textsf{INITIAL}}$ - for new installations
- $\color{#ff7b72}{\textsf{YOUR WORKSPACE}}$ - APEX target workspace name
- $\color{#ff7b72}{\textsf{APP ID}}$ - target APEX id (default is 1200)
- $\color{#ff7b72}{\textsf{USE ID OFFSET}}$ - in cases where this APP is already installed at least once under the same APEX Instance, you must set it to 'Y' to avoid conflict with existing APEX app components. If this is the first and only app installation, set it to 'N'.
- $\color{#ff7b72}{\textsf{ALLOW OVERWRITE}}$ - If target APP_ID already exists in target APEX <b><u>Instance</u></b> it will overwrite it. <u>Make sure this is correct!</u>
- $\color{#ff7b72}{\textsf{AUTH SCHEME NAME}}$ - target APP's authentication scheme. APEX's default is $\color{#f7ee78}{\textsf{'Oracle APEX Accounts'}}$ . A 2nd option is $\color{#a5d6ff}{\textsf{'OCI SSO'}}$ but that requires configuring the workspace/app with OAuth for external authentication. Check below for an example of integrating Oracle APEX with OCI IAM domains:
https://docs.oracle.com/en/learn/apex-identitydomains-sso/index.html


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
    p_use_id_offset    => 'N',
    p_auth_scheme_name => 'Oracle APEX Accounts', -- or "OCI SSO" for federated login
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
