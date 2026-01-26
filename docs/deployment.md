# Deployment

Home: [README](../README.md) · **Docs** · **Deployment**

This document describes **initial installation** of the application bundle into an Autonomous Database / APEX workspace.

Updates after the first install are performed **in-app**. See [Update](update.md).

---

## How deployment works (1 minute)
Deployment is performed by a database-resident **Deployment Manager** implemented in PL/SQL (`DEPLOY_MGR_PKG`).

- You upload a **bundle ZIP** into the database (stored as a BLOB)
- The Deployment Manager applies its contents directly (no manual ZIP extraction)
- Every deployment creates a **run record** and detailed logs for auditability

---

## What’s in a bundle
A bundle is a ZIP with a manifest and install scripts. Example manifest:

``` json
{
  "app_id": 1200,
  "version": "v20260109_134227",
  "schema": "ORDS_PLSQL_GATEWAY",
  "created_at": "2026-01-09T13:42:30.742+00:00",
  "notes": "Credentials are not exported; ensure required credentials exist per environment."
}
```

> Note: credentials and environment-specific values are intentionally **not** exported.  
> Each environment must provide its own configuration and OCI/IAM setup.

---

## Prerequisites
Before running an initial deployment, confirm:
- [Infrastructure Requirements](infra-requirements.md) are met
- You have a target APEX workspace and know its name
- You have the application bundle ZIP ready to upload

---

## Step 1 — Run the admin prerequisite script (mandatory)
**Script:** `ov_run_as_admin.sql`  
**Run as:** `ADMIN` (or an equivalent privileged user)

Purpose (high level):
- grants required privileges
- enables required packages (scheduler, APEX APIs, DBMS_CLOUD, etc.)
- prepares the environment for import

---

## Step 2 — Upload the bundle ZIP into `DEPLOY_BUNDLES`
Upload the ZIP as a BLOB (method depends on your tooling).  
Once uploaded, you should have a `BUNDLE_ID` to deploy.

---

## Step 3 — Deploy (INITIAL mode)
Call the Deployment Manager in **INITIAL** mode. Example:

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

If you want to allow overwriting an existing app (only for controlled scenarios), use the overwrite flag:

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

If you are installing into a new workspace or need APEX ID offsetting, use the offset option:

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

## Step 4 — Validate the deployment
Check the deployment run and applied components:

```SELECT * FROM deploy_runs ORDER BY run_id DESC;```

```SELECT * FROM deploy_applied ORDER BY applied_at DESC;```

Recommended validation checks:
- app opens successfully in APEX
- home dashboard renders (even if data is empty initially)
- background jobs are created (enabled/disabled per your chosen settings)
- `APP_CONFIG` rows exist for the application

---

## After installation
Next steps are typically:
1. Complete environment configuration in [Configuration](configuration.md)
2. Enable and monitor scheduled refresh jobs in [Administration & Operations](admin-guide.md)
3. If using the chatbot, verify GenAI permissions and chatbot parameters in [NL2SQL Chatbot](chatbot.md)

---
