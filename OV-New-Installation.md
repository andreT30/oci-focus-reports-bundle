For new OV installations:
--- 
Install deploy manager ddl
Install deploy manager pkg
Insert new row to deploy budnles and upload zip
---
Install:
DECLARE
  l_run_id   NUMBER;
  l_job_name VARCHAR2(128);
BEGIN
  deploy_mgr_pkg.enqueue_deploy(
    p_bundle_id         => <bundle_id_on_target>,
    p_enable_jobs_after => FALSE,
    p_dry_run           => FALSE,
    o_run_id            => l_run_id,
    o_job_name          => l_job_name
  );
END;
/

Monitor:
SELECT * FROM deploy_runs ORDER BY run_id DESC;
SELECT * FROM deploy_applied ORDER BY applied_at DESC;
