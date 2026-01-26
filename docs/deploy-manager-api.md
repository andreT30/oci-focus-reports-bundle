# Deployment Manager API (`DEPLOY_MGR_PKG`)

Home: [README](../README.md) · **Docs** · **Deployment Manager API**

This document summarizes the **operational** API surface of the Deployment Manager.
It focuses on the calls you typically need for:
- exporting a backup bundle
- deploying a bundle (initial install or update automation)

For the UI-based flows, see:
- [Backup / Export](backup-export.md)
- [Deployment](deployment.md)
- [Update](update.md)

---

## Export bundle
Exports the current installation into a new bundle ZIP stored in the database.

```sql
FUNCTION export_bundle(
  p_app_id       IN NUMBER,
  p_version_tag  IN VARCHAR2,
  p_include_jobs IN BOOLEAN DEFAULT TRUE
) RETURN NUMBER;
```

Example:

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

## Deploy bundle
Applies a bundle ZIP already stored as a BLOB in `DEPLOY_BUNDLES`.

```sql
PROCEDURE enqueue_deploy(
  p_bundle_id         IN NUMBER,
  p_enable_jobs_after IN BOOLEAN DEFAULT FALSE,
  p_dry_run           IN BOOLEAN DEFAULT FALSE,
  o_run_id            OUT NUMBER,
  o_job_name          OUT VARCHAR2
);
```

Example:

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
- Bundle export/import is designed to be environment-portable.
- Credentials and environment-specific identifiers are not exported.
