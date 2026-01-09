# Deployment Manager API (DEPLOY_MGR_PKG)

This document describes the **supported Deployment Manager API surface**
intended for operational use.

Only the APIs required for **export** and **import (deployment)** are documented here.

---

## Export Bundle

Exports the current application state into a new bundle ZIP stored in the database.

```sql
FUNCTION export_bundle(
  p_app_id       IN NUMBER,
  p_version_tag  IN VARCHAR2,
  p_include_jobs IN BOOLEAN DEFAULT TRUE
) RETURN NUMBER;
```

### Example
```sql
DECLARE
  l_bundle_id NUMBER;
BEGIN
  l_bundle_id := deploy_mgr_pkg.export_bundle(
                   p_app_id       => 1200,
                   p_version_tag  => 'v1.0.0',
                   p_include_jobs => TRUE
                 );

  DBMS_OUTPUT.PUT_LINE('BUNDLE_ID='||l_bundle_id);
END;
/
```

---

## Import / Deploy Bundle (scheduled job only)

Deployment is performed **as a scheduler job**.

```sql
PROCEDURE enqueue_deploy(
  p_bundle_id         IN NUMBER,
  p_enable_jobs_after IN BOOLEAN DEFAULT FALSE,
  p_dry_run           IN BOOLEAN DEFAULT FALSE,
  o_run_id            OUT NUMBER,
  o_job_name          OUT VARCHAR2
);
```

### Example
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

## Notes

- Synchronous deploy APIs are intentionally not documented.
- `p_dry_run` is intended for **update scenarios only**.
- Scheduler jobs defined in `db/ddl/90_jobs.sql` are created disabled by default.
- Deployment status and logs must be checked via deployment run tables or admin UI.
