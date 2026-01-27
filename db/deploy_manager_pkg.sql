CREATE OR REPLACE PACKAGE deploy_mgr_pkg AS
  FUNCTION export_bundle(
    p_app_id       IN NUMBER,
    p_version_tag  IN VARCHAR2,
    p_include_jobs IN BOOLEAN DEFAULT TRUE
  ) RETURN NUMBER;

  PROCEDURE deploy_bundle(
    p_bundle_id         IN NUMBER,
    p_enable_jobs_after IN BOOLEAN DEFAULT FALSE,
    p_dry_run           IN BOOLEAN DEFAULT FALSE
  );

  -- Execute an arbitrary SQL/PLSQL script (CLOB) under deploy logging.
  PROCEDURE exec_script_clob(
    p_script      IN CLOB,
    p_script_name IN VARCHAR2,
    p_dry_run     IN BOOLEAN DEFAULT FALSE
  );

  FUNCTION get_latest_bundle_id(p_app_id IN NUMBER) RETURN NUMBER;
  FUNCTION blob_to_clob(p_blob IN BLOB) RETURN CLOB;
  FUNCTION clob_to_blob(p_clob IN CLOB) RETURN BLOB;

  PROCEDURE enqueue_deploy(
    p_bundle_id         IN NUMBER,
    p_enable_jobs_after IN BOOLEAN DEFAULT FALSE,
    p_dry_run           IN BOOLEAN DEFAULT FALSE,
    p_install_mode      IN VARCHAR2 DEFAULT 'UPDATE', -- 'INITIAL'/'UPDATE'
    p_workspace_name    IN VARCHAR2 DEFAULT NULL,     -- only used for INITIAL
    p_app_id            IN NUMBER   DEFAULT NULL,     -- only used for INITIAL
    p_auth_scheme_name  IN VARCHAR2 DEFAULT 'Oracle APEX Accounts', -- Default Auth Scheme
    p_allow_overwrite   IN VARCHAR2 DEFAULT 'N',      -- 'Y'/'N' (INITIAL only)
    p_use_id_offset     IN VARCHAR2 DEFAULT 'N',      -- 'Y'/'N' (INITIAL only)
    o_run_id            OUT NUMBER,
    o_job_name          OUT VARCHAR2
  );
  -- Scheduler worker MUST use SQL types (no BOOLEAN args)
    -- Job for deploy bundle (SQL-typed args; scheduler cannot pass BOOLEAN)
  -- p_install_mode:
  --   - 'INITIAL' : bootstrap APP_CONFIG with p_workspace_name + p_app_id then deploy
  --   - 'UPDATE'  : deploy using existing APP_CONFIG values
  -- Job for deploy bundle (SQL-typed args; scheduler cannot pass BOOLEAN)
  -- p_install_mode:
  --   - 'INITIAL' : bootstrap APP_CONFIG with p_workspace_name + p_app_id then deploy
  --   - 'UPDATE'  : deploy using existing APP_CONFIG values
  PROCEDURE deploy_worker(
    p_run_id            IN NUMBER,
    p_bundle_id         IN NUMBER,
    p_enable_jobs_after IN VARCHAR2, -- 'Y'/'N'
    p_dry_run           IN VARCHAR2, -- 'Y'/'N'
    p_install_mode      IN VARCHAR2, -- 'INITIAL'/'UPDATE'
    p_workspace_name    IN VARCHAR2, -- required for INITIAL
    p_app_id            IN NUMBER,   -- required for INITIAL
    p_allow_overwrite   IN VARCHAR2, -- 'Y'/'N' (INITIAL only)
    p_use_id_offset     IN VARCHAR2, -- 'Y'/'N' (INITIAL only)
    p_auth_scheme_name  IN VARCHAR2  
  );
END deploy_mgr_pkg;
/

create or replace PACKAGE BODY deploy_mgr_pkg AS

  ------------------------------------------------------------------------------
  -- Logging helpers
  ------------------------------------------------------------------------------
  PROCEDURE run_log(p_run_id IN NUMBER, p_msg IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE deploy_runs
      SET log_clob =
            CASE WHEN log_clob IS NULL THEN TO_CLOB('') ELSE log_clob END
            || TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS.FF3')
            || ' ' || p_msg || CHR(10)
    WHERE run_id = p_run_id;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      -- do not raise from autonomous logger (prevents ORA-06519 masking real errors)
      NULL;
  END;

  PROCEDURE run_ok(p_run_id IN NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE deploy_runs
      SET status   = 'SUCCESS',
          ended_at = SYSTIMESTAMP
    WHERE run_id = p_run_id;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      NULL;
  END;

  PROCEDURE run_fail(p_run_id IN NUMBER, p_err CLOB) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE deploy_runs
      SET status      = 'FAILED',
          ended_at    = SYSTIMESTAMP,
          error_stack = p_err
    WHERE run_id = p_run_id;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      NULL;
  END;

  --- Source data helpers
  FUNCTION table_exists(p_table_name IN VARCHAR2) RETURN BOOLEAN IS
    l_cnt NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO l_cnt
      FROM user_tables
    WHERE table_name = UPPER(p_table_name);
    RETURN l_cnt > 0;
  END;

  PROCEDURE append_line(p_out IN OUT NOCOPY CLOB, p_line IN VARCHAR2) IS
  BEGIN
    IF p_out IS NULL THEN
      DBMS_LOB.CREATETEMPORARY(p_out, TRUE);
    END IF;
    DBMS_LOB.APPEND(p_out, p_line || CHR(10));
  END;

  ------- Autonomous start
  FUNCTION run_start(p_action IN VARCHAR2, p_bundle_id IN NUMBER DEFAULT NULL) RETURN NUMBER IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_run_id NUMBER;
  BEGIN
    INSERT INTO deploy_runs(bundle_id, action, status)
    VALUES (p_bundle_id, p_action, 'RUNNING')
    RETURNING run_id INTO l_run_id;
    COMMIT;
    RETURN l_run_id;
  END;

  ------------------------------------------------------------------------------
  -- CLOB <-> BLOB conversion (UTF-8)
  ------------------------------------------------------------------------------
  FUNCTION clob_to_blob(p_clob IN CLOB) RETURN BLOB IS
    l_blob    BLOB;
    l_dst_ofs INTEGER := 1;
    l_src_ofs INTEGER := 1;
    l_langctx INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
    l_warn    INTEGER;
  BEGIN
    IF p_clob IS NULL THEN
      RETURN NULL;
    END IF;

    DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
    DBMS_LOB.CONVERTTOBLOB(
      dest_lob     => l_blob,
      src_clob     => p_clob,
      amount       => DBMS_LOB.LOBMAXSIZE,
      dest_offset  => l_dst_ofs,
      src_offset   => l_src_ofs,
      blob_csid    => NLS_CHARSET_ID('AL32UTF8'),
      lang_context => l_langctx,
      warning      => l_warn
    );
    RETURN l_blob;
  END;

  FUNCTION blob_to_clob(p_blob IN BLOB) RETURN CLOB IS
    l_clob    CLOB;
    l_dst_ofs INTEGER := 1;
    l_src_ofs INTEGER := 1;
    l_langctx INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
    l_warn    INTEGER;
  BEGIN
    IF p_blob IS NULL THEN
      RETURN NULL;
    END IF;

    DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
    DBMS_LOB.CONVERTTOCLOB(
      dest_lob     => l_clob,
      src_blob     => p_blob,
      amount       => DBMS_LOB.LOBMAXSIZE,
      dest_offset  => l_dst_ofs,
      src_offset   => l_src_ofs,
      blob_csid    => NLS_CHARSET_ID('AL32UTF8'),
      lang_context => l_langctx,
      warning      => l_warn
    );
    RETURN l_clob;
  END;

  ------------------------------------------------------------------------------
  -- DBMS_METADATA helpers
  ------------------------------------------------------------------------------
  PROCEDURE md_setup IS
  BEGIN
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SEGMENT_ATTRIBUTES', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'TABLESPACE', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'CONSTRAINTS', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'REF_CONSTRAINTS', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'EMIT_SCHEMA', FALSE);
  END;

  ------------------------------------------------------------------------------
  -- Strip exporting schema prefix from stored procedure references (jobs/actions)
  ------------------------------------------------------------------------------
  FUNCTION strip_schema_prefix(p_txt IN VARCHAR2) RETURN VARCHAR2 IS
    l_txt VARCHAR2(32767) := p_txt;
  BEGIN
    IF l_txt IS NULL THEN
      RETURN NULL;
    END IF;

    -- Remove references to the exporting schema only (quoted/unquoted)
    l_txt := REGEXP_REPLACE(
              l_txt,
              '("?'||USER||'"?)\.',
              '',
              1, 0, 'i'
            );

    RETURN l_txt;
  END strip_schema_prefix;
  FUNCTION get_ddl_safe(p_type IN VARCHAR2, p_name IN VARCHAR2) RETURN CLOB IS
    l_ddl CLOB;
    l_t   VARCHAR2(128) := UPPER(p_type);
  BEGIN
    l_ddl := DBMS_METADATA.GET_DDL(l_t, UPPER(p_name));

    -- remove table-level default collation (APEX unsafe)
    l_ddl := REGEXP_REPLACE(l_ddl, '\s+DEFAULT\s+COLLATION\s+"[^"]+"', '', 1, 0, 'i');

    -- remove per-column collation (APEX unsafe)
    l_ddl := REGEXP_REPLACE(l_ddl, '\s+COLLATE\s+"[^"]+"', '', 1, 0, 'i');

    -- Materialized view cleanup (avoid ORA-12990 + env-specific options)
    IF l_t IN ('MATERIALIZED_VIEW','MATERIALIZED VIEW') THEN
      -- remove obsolete clause
      l_ddl := REGEXP_REPLACE(
                l_ddl,
                '\s+USING\s+DEFAULT\s+LOCAL\s+ROLLBACK\s+SEGMENT\b',
                '',
                1, 0, 'in'
              );

      -- remove query computation / rewrite / concurrent refresh options (can duplicate / differ by DB)
      l_ddl := REGEXP_REPLACE(l_ddl, '\s+ON\s+QUERY\s+COMPUTATION(\s+(ENABLE|DISABLE))?', '', 1, 0, 'in');
      l_ddl := REGEXP_REPLACE(l_ddl, '\s+(ENABLE|DISABLE)?\s*QUERY\s+REWRITE\b',           '', 1, 0, 'in');
      l_ddl := REGEXP_REPLACE(l_ddl, '\s+(ENABLE|DISABLE)?\s*CONCURRENT\s+REFRESH\b',      '', 1, 0, 'in');

      -- also strip "USING ENFORCED CONSTRAINTS" if it appears (often paired with the above)
      l_ddl := REGEXP_REPLACE(l_ddl, '\s+USING\s+ENFORCED\s+CONSTRAINTS\b', '', 1, 0, 'in');
    END IF;

    RETURN l_ddl;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '/* FAILED GET_DDL '||p_type||' '||p_name||' : '||SQLERRM||' */'||CHR(10);
  END;

  ------------------------------------------------------------------------------
  -- Context export (CREATE CONTEXT)
  ------------------------------------------------------------------------------
  FUNCTION export_contexts RETURN CLOB IS
    l_out CLOB := EMPTY_CLOB();
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_out, TRUE);

    DBMS_LOB.APPEND(
      l_out,
        '/* Contexts (hardcoded) */' || CHR(10) || CHR(10) ||

        'BEGIN' || CHR(10) ||
        '  EXECUTE IMMEDIATE ''CREATE OR REPLACE CONTEXT CHATBOT_ENV USING CHATBOT_ENV_PKG'';' || CHR(10) ||
        'END;' || CHR(10) ||
        '/' || CHR(10) || CHR(10)
    );

    RETURN l_out;
  END;

  ------------------------------------------------------------------------------
  -- Job export (basic; secrets/credentials are NOT exported)
  --  - If job does not exist on target: CREATE_JOB
  --  - If job exists:
  --      * If job_type differs: DROP + CREATE (Policy A)
  --      * Else: DISABLE, SET_ATTRIBUTE/SET_ATTRIBUTE_NULL, then ENABLE per policy
  ------------------------------------------------------------------------------
  FUNCTION export_jobs RETURN CLOB IS
    l_out     CLOB := EMPTY_CLOB();
    l_action  VARCHAR2(32767);
    l_repeat  VARCHAR2(32767);
    l_comm    VARCHAR2(32767);
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_out, TRUE);

    DBMS_LOB.APPEND(
      l_out,
        '/* Scheduler jobs exported as CREATE_JOB blocks (with UPDATE via SET_ATTRIBUTE).'||CHR(10)||
        '   NOTE: Credentials/secrets are NOT exported. Ensure required credentials exist per environment.'||CHR(10)||
        '   Enabled/disabled logic:'||CHR(10)||
        '   - If job exists on target and source is ENABLED: keep target enabled state.'||CHR(10)||
        '   - If source is DISABLED: force job disabled on target.'||CHR(10)||
        '   - If job does not exist on target: new job follows source enabled flag.'||CHR(10)||
        '   Update logic:'||CHR(10)||
        '   - If job exists and job_type differs: DROP + CREATE (Policy A).'||CHR(10)||
        '   - Else: disable job, update changed attributes, then enable/disable per policy.'||CHR(10)||
        '*/'||CHR(10)||CHR(10)
    );

    FOR j IN (
      SELECT job_name, job_type, job_action, repeat_interval, start_date, enabled, comments
        FROM user_scheduler_jobs
      ORDER BY job_name
    ) LOOP

      IF j.job_type IN ('PLSQL_BLOCK','STORED_PROCEDURE') THEN

        -- Escape chosen q-quote delimiter (~). If it appears, double it.
        l_action := REPLACE(NVL(strip_schema_prefix(j.job_action), ''), '~', '~~');
        l_repeat := REPLACE(NVL(j.repeat_interval, ''), '~', '~~');
        l_comm   := REPLACE(NVL(j.comments, ''), '~', '~~');

        DBMS_LOB.APPEND(
          l_out,
            'DECLARE' || CHR(10) ||
            '  l_target_enabled  VARCHAR2(5);' || CHR(10) ||
            '  l_exists          NUMBER := 0;' || CHR(10) ||
            CHR(10) ||
            '  -- Current (target) attributes' || CHR(10) ||
            '  l_job_type        VARCHAR2(30);' || CHR(10) ||
            '  l_job_action      VARCHAR2(4000);' || CHR(10) ||
            '  l_repeat_interval VARCHAR2(4000);' || CHR(10) ||
            '  l_start_date      TIMESTAMP WITH TIME ZONE;' || CHR(10) ||
            '  l_comments        VARCHAR2(4000);' || CHR(10) ||
            CHR(10) ||
            '  -- Desired (source) attributes' || CHR(10) ||
            '  d_job_type        VARCHAR2(30)   := ''' || j.job_type || ''';' || CHR(10) ||
            '  d_job_action      VARCHAR2(4000) := q''~' || l_action || '~'';' || CHR(10) ||
            CASE
              WHEN j.repeat_interval IS NOT NULL THEN
                '  d_repeat_interval VARCHAR2(4000) := q''~' || l_repeat || '~'';' || CHR(10)
              ELSE
                '  d_repeat_interval VARCHAR2(4000) := NULL;' || CHR(10)
            END ||
            CASE
              WHEN j.start_date IS NOT NULL THEN
                '  d_start_date      TIMESTAMP WITH TIME ZONE := TO_TIMESTAMP_TZ(''' ||
                TO_CHAR(j.start_date, 'YYYY-MM-DD"T"HH24:MI:SS.FF TZH:TZM') ||
                ''',''YYYY-MM-DD"T"HH24:MI:SS.FF TZH:TZM'');' || CHR(10)
              ELSE
                '  d_start_date      TIMESTAMP WITH TIME ZONE := NULL;' || CHR(10)
            END ||
            CASE
              WHEN j.comments IS NOT NULL THEN
                '  d_comments        VARCHAR2(4000) := q''~' || l_comm || '~'';' || CHR(10)
              ELSE
                '  d_comments        VARCHAR2(4000) := NULL;' || CHR(10)
            END ||
            'BEGIN' || CHR(10) ||
            '  -- Detect existence + current enabled state' || CHR(10) ||
            '  BEGIN' || CHR(10) ||
            '    SELECT enabled' || CHR(10) ||
            '      INTO l_target_enabled' || CHR(10) ||
            '      FROM user_scheduler_jobs' || CHR(10) ||
            '     WHERE job_name = ''' || j.job_name || ''';' || CHR(10) ||
            '    l_exists := 1;' || CHR(10) ||
            '  EXCEPTION' || CHR(10) ||
            '    WHEN NO_DATA_FOUND THEN' || CHR(10) ||
            '      l_target_enabled := NULL;' || CHR(10) ||
            '      l_exists := 0;' || CHR(10) ||
            '  END;' || CHR(10) ||
            CHR(10) ||
            '  -- Enabled/disabled policy' || CHR(10) ||
            '  IF l_target_enabled IS NULL THEN' || CHR(10) ||
            '    -- Job does not exist on target: follow source enabled flag' || CHR(10) ||
            '    l_target_enabled := ''' || CASE WHEN j.enabled = 'TRUE' THEN 'TRUE' ELSE 'FALSE' END || ''';' || CHR(10) ||
            '  ELSIF ''' || j.enabled || ''' = ''FALSE'' THEN' || CHR(10) ||
            '    -- Job disabled on source: force disabled on target' || CHR(10) ||
            '    l_target_enabled := ''FALSE'';' || CHR(10) ||
            '  END IF;' || CHR(10) ||
            CHR(10) ||
            '  IF l_exists = 1 THEN' || CHR(10) ||
            '    -- Read current attributes' || CHR(10) ||
            '    SELECT job_type, job_action, repeat_interval, start_date, comments' || CHR(10) ||
            '      INTO l_job_type, l_job_action, l_repeat_interval, l_start_date, l_comments' || CHR(10) ||
            '      FROM user_scheduler_jobs' || CHR(10) ||
            '     WHERE job_name = ''' || j.job_name || ''';' || CHR(10) ||
            CHR(10) ||
            '    ----------------------------------------------------------------' || CHR(10) ||
            '    -- Policy A: if job_type differs, DROP + CREATE' || CHR(10) ||
            '    ----------------------------------------------------------------' || CHR(10) ||
            '    IF NVL(l_job_type,''#'') <> NVL(d_job_type,''#'') THEN' || CHR(10) ||
            '      BEGIN' || CHR(10) ||
            '        DBMS_SCHEDULER.DISABLE(''' || j.job_name || ''', force => TRUE);' || CHR(10) ||
            '      EXCEPTION WHEN OTHERS THEN NULL; END;' || CHR(10) ||
            CHR(10) ||
            '      BEGIN' || CHR(10) ||
            '        DBMS_SCHEDULER.DROP_JOB(job_name => ''' || j.job_name || ''', force => TRUE);' || CHR(10) ||
            '      EXCEPTION WHEN OTHERS THEN NULL; END;' || CHR(10) ||
            CHR(10) ||
            '      DBMS_SCHEDULER.CREATE_JOB(' || CHR(10) ||
            '        job_name        => ''' || j.job_name || ''',' || CHR(10) ||
            '        job_type        => d_job_type,' || CHR(10) ||
            '        job_action      => d_job_action,' || CHR(10) ||
            CASE
              WHEN j.repeat_interval IS NOT NULL THEN
                '        repeat_interval => d_repeat_interval,' || CHR(10)
              ELSE
                ''
            END ||
            CASE
              WHEN j.start_date IS NOT NULL THEN
                '        start_date      => d_start_date,' || CHR(10)
              ELSE
                ''
            END ||
            '        enabled         => (NVL(l_target_enabled, ''FALSE'') = ''TRUE''),' || CHR(10) ||
            '        auto_drop       => FALSE' || CHR(10) ||
            CASE
              WHEN j.comments IS NOT NULL THEN
                '      , comments        => d_comments' || CHR(10)
              ELSE
                ''
            END ||
            '      );' || CHR(10) ||
            CHR(10) ||
            '      -- Enforce disabled if policy says disabled' || CHR(10) ||
            '      IF NVL(l_target_enabled, ''FALSE'') <> ''TRUE'' THEN' || CHR(10) ||
            '        BEGIN DBMS_SCHEDULER.DISABLE(''' || j.job_name || ''', force => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;' || CHR(10) ||
            '      END IF;' || CHR(10) ||
            CHR(10) ||
            '    ELSE' || CHR(10) ||
            '      --------------------------------------------------------------' || CHR(10) ||
            '      -- Same job_type: DISABLE + SET_ATTRIBUTE where needed' || CHR(10) ||
            '      --------------------------------------------------------------' || CHR(10) ||
            '      DBMS_SCHEDULER.DISABLE(''' || j.job_name || ''', force => TRUE);' || CHR(10) ||
            CHR(10) ||
            '      -- job_action' || CHR(10) ||
            '      IF NVL(l_job_action,''#'') <> NVL(d_job_action,''#'') THEN' || CHR(10) ||
            '        DBMS_SCHEDULER.SET_ATTRIBUTE(' || CHR(10) ||
            '          name      => ''' || j.job_name || ''',' || CHR(10) ||
            '          attribute => ''job_action'',' || CHR(10) ||
            '          value     => d_job_action' || CHR(10) ||
            '        );' || CHR(10) ||
            '      END IF;' || CHR(10) ||
            CHR(10) ||
            '      -- repeat_interval' || CHR(10) ||
            '      IF d_repeat_interval IS NULL THEN' || CHR(10) ||
            '        IF l_repeat_interval IS NOT NULL THEN' || CHR(10) ||
            '          DBMS_SCHEDULER.SET_ATTRIBUTE_NULL(' || CHR(10) ||
            '            name      => ''' || j.job_name || ''',' || CHR(10) ||
            '            attribute => ''repeat_interval''' || CHR(10) ||
            '          );' || CHR(10) ||
            '        END IF;' || CHR(10) ||
            '      ELSIF NVL(l_repeat_interval,''#'') <> NVL(d_repeat_interval,''#'') THEN' || CHR(10) ||
            '        DBMS_SCHEDULER.SET_ATTRIBUTE(' || CHR(10) ||
            '          name      => ''' || j.job_name || ''',' || CHR(10) ||
            '          attribute => ''repeat_interval'',' || CHR(10) ||
            '          value     => d_repeat_interval' || CHR(10) ||
            '        );' || CHR(10) ||
            '      END IF;' || CHR(10) ||
            CHR(10) ||
            '      -- start_date' || CHR(10) ||
            '      IF d_start_date IS NULL THEN' || CHR(10) ||
            '        IF l_start_date IS NOT NULL THEN' || CHR(10) ||
            '          DBMS_SCHEDULER.SET_ATTRIBUTE_NULL(' || CHR(10) ||
            '            name      => ''' || j.job_name || ''',' || CHR(10) ||
            '            attribute => ''start_date''' || CHR(10) ||
            '          );' || CHR(10) ||
            '        END IF;' || CHR(10) ||
            '      ELSIF l_start_date IS NULL OR l_start_date <> d_start_date THEN' || CHR(10) ||
            '        DBMS_SCHEDULER.SET_ATTRIBUTE(' || CHR(10) ||
            '          name      => ''' || j.job_name || ''',' || CHR(10) ||
            '          attribute => ''start_date'',' || CHR(10) ||
            '          value     => d_start_date' || CHR(10) ||
            '        );' || CHR(10) ||
            '      END IF;' || CHR(10) ||
            CHR(10) ||
            '      -- comments' || CHR(10) ||
            '      IF d_comments IS NULL THEN' || CHR(10) ||
            '        IF l_comments IS NOT NULL THEN' || CHR(10) ||
            '          DBMS_SCHEDULER.SET_ATTRIBUTE_NULL(' || CHR(10) ||
            '            name      => ''' || j.job_name || ''',' || CHR(10) ||
            '            attribute => ''comments''' || CHR(10) ||
            '          );' || CHR(10) ||
            '        END IF;' || CHR(10) ||
            '      ELSIF NVL(l_comments,''#'') <> NVL(d_comments,''#'') THEN' || CHR(10) ||
            '        DBMS_SCHEDULER.SET_ATTRIBUTE(' || CHR(10) ||
            '          name      => ''' || j.job_name || ''',' || CHR(10) ||
            '          attribute => ''comments'',' || CHR(10) ||
            '          value     => d_comments' || CHR(10) ||
            '        );' || CHR(10) ||
            '      END IF;' || CHR(10) ||
            CHR(10) ||
            '      -- auto_drop (you force FALSE everywhere)' || CHR(10) ||
            '      DBMS_SCHEDULER.SET_ATTRIBUTE(' || CHR(10) ||
            '        name      => ''' || j.job_name || ''',' || CHR(10) ||
            '        attribute => ''auto_drop'',' || CHR(10) ||
            '        value     => FALSE' || CHR(10) ||
            '      );' || CHR(10) ||
            CHR(10) ||
            '      -- Enable/disable per policy' || CHR(10) ||
            '      IF NVL(l_target_enabled, ''FALSE'') = ''TRUE'' THEN' || CHR(10) ||
            '        DBMS_SCHEDULER.ENABLE(''' || j.job_name || ''');' || CHR(10) ||
            '      END IF;' || CHR(10) ||
            '    END IF;' || CHR(10) ||
            CHR(10) ||
            '  ELSE' || CHR(10) ||
            '    -- Create new job (no REPLACE parameter on this DB version)' || CHR(10) ||
            '    DBMS_SCHEDULER.CREATE_JOB(' || CHR(10) ||
            '      job_name        => ''' || j.job_name || ''',' || CHR(10) ||
            '      job_type        => d_job_type,' || CHR(10) ||
            '      job_action      => d_job_action,' || CHR(10) ||
            CASE
              WHEN j.repeat_interval IS NOT NULL THEN
                '      repeat_interval => d_repeat_interval,' || CHR(10)
              ELSE
                ''
            END ||
            CASE
              WHEN j.start_date IS NOT NULL THEN
                '      start_date      => d_start_date,' || CHR(10)
              ELSE
                ''
            END ||
            '      enabled         => (NVL(l_target_enabled, ''FALSE'') = ''TRUE''),' || CHR(10) ||
            '      auto_drop       => FALSE' || CHR(10) ||
            CASE
              WHEN j.comments IS NOT NULL THEN
                '    ,'||'  comments        => d_comments' || CHR(10)
              ELSE
                ''
            END ||
            '    );' || CHR(10) ||
            '  END IF;' || CHR(10) ||
            'END;' || CHR(10) || '/' || CHR(10) || CHR(10)
        );

      ELSE
        DBMS_LOB.APPEND(
          l_out,
            '/* Job ' || j.job_name || ' job_type=' || j.job_type ||
            ' not auto-exported. Recreate manually if needed. */' || CHR(10) || CHR(10)
        );
      END IF;

    END LOOP;

    RETURN l_out;
  END;

  ------------------------------------------------------------------------------
  -- APP_CONFIG helper (no compile-time dependency)
  ------------------------------------------------------------------------------
  FUNCTION get_app_config_value(p_key IN VARCHAR2) RETURN VARCHAR2 IS
    l_val VARCHAR2(32767);
  BEGIN
    -- dynamic SQL avoids compile-time dependency on APP_CONFIG
    EXECUTE IMMEDIATE
      'SELECT config_value FROM app_config WHERE config_key = :1'
      INTO l_val
      USING p_key;

    RETURN l_val;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;

    WHEN OTHERS THEN
      -- If APP_CONFIG doesn't exist (ORA-00942), or any other issue, return NULL.
      -- (You can optionally log if deploy_runs exists, but keep this simple.)
      IF SQLCODE = -942 THEN
        RETURN NULL;
      END IF;
      RETURN NULL;
  END get_app_config_value;

  ------------------------------------------------------------------------------
  -- APEX Offset helpers
  ------------------------------------------------------------------------------  
  FUNCTION get_app_offset(
    p_run_id   IN NUMBER,
    p_ws_name  IN VARCHAR2,
    p_app_id   IN NUMBER
  ) RETURN NUMBER
  IS
    l_val VARCHAR2(4000);
    l_key VARCHAR2(200);
  BEGIN
    -- Prefer app-specific key (most deterministic)
    l_key := 'APEX_ID_OFFSET_APP';

    l_val := get_app_config_value(l_key);  -- whatever your existing config getter is
    IF l_val IS NOT NULL THEN
      RETURN TO_NUMBER(TRIM(l_val));
    END IF;

    RETURN 0;
  EXCEPTION
    WHEN VALUE_ERROR THEN
      run_log(p_run_id, 'Invalid numeric value for '||l_key||'="'||NVL(l_val,'NULL')||'". Using 0.');
      RETURN 0;
    WHEN OTHERS THEN
      -- if missing key, just 0
      RETURN 0;
  END;

  ------------------------------------------------------------------------------
  -- APP_CONFIG bootstrap + APEX target resolution
  ------------------------------------------------------------------------------
  PROCEDURE ensure_app_config_table(p_run_id IN NUMBER, p_dry_run IN BOOLEAN) IS
  BEGIN
    IF p_dry_run THEN
      run_log(p_run_id, 'DRY-RUN: would ensure APP_CONFIG exists');
      RETURN;
    END IF;

    BEGIN
      EXECUTE IMMEDIATE q'[
        CREATE TABLE app_config (
          config_key   VARCHAR2(4000) PRIMARY KEY,
          config_value VARCHAR2(32767),
          updated_at   DATE
        )
      ]';
      run_log(p_run_id, 'Created APP_CONFIG table.');
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -955 THEN
          NULL; -- already exists
        ELSE
          RAISE;
        END IF;
    END;
  END ensure_app_config_table;

  PROCEDURE upsert_app_config(
    p_run_id  IN NUMBER,
    p_key     IN VARCHAR2,
    p_val     IN VARCHAR2,
    p_dry_run IN BOOLEAN
  ) IS
  BEGIN
    IF p_dry_run THEN
      run_log(p_run_id, 'DRY-RUN: would set APP_CONFIG '||p_key||'='||NVL(p_val,'<null>'));
      RETURN;
    END IF;

    EXECUTE IMMEDIATE q'[
      MERGE INTO app_config c
      USING (SELECT :k config_key, :v config_value FROM dual) s
      ON (c.config_key = s.config_key)
      WHEN MATCHED THEN UPDATE SET c.config_value = s.config_value, c.updated_at = SYSDATE
      WHEN NOT MATCHED THEN INSERT (config_key, config_value, updated_at)
        VALUES (s.config_key, s.config_value, SYSDATE)
    ]' USING p_key, p_val;

    run_log(p_run_id, 'APP_CONFIG set: '||p_key);
  END upsert_app_config;

  PROCEDURE resolve_apex_target(
    p_run_id     IN NUMBER,
    o_workspace  OUT VARCHAR2,
    o_app_id     OUT NUMBER
  ) IS
    l_app_id_txt VARCHAR2(32767);
  BEGIN
    o_workspace  := get_app_config_value('APEX_WORKSPACE_NAME');
    l_app_id_txt := get_app_config_value('APEX_APP_ID');

    IF o_workspace IS NULL OR l_app_id_txt IS NULL THEN
      raise_application_error(-20020,
        'Missing APP_CONFIG keys APEX_WORKSPACE_NAME and/or APEX_APP_ID. Use enqueue_deploy with p_install_mode=INITIAL first.');
    END IF;

    BEGIN
      o_app_id := TO_NUMBER(TRIM(l_app_id_txt));
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20021,
          'Invalid APP_CONFIG APEX_APP_ID value: '||SUBSTR(l_app_id_txt,1,200));
    END;
  END resolve_apex_target;
  ------------------------------------------------------------------------------
  -- APP_CONFIG seed export (selected keys -> MERGE statements)
  ------------------------------------------------------------------------------
  FUNCTION export_app_config RETURN CLOB IS
    l_out    CLOB := EMPTY_CLOB();

    -- local row vars
    l_key    VARCHAR2(4000);
    l_val    CLOB;

    l_expr   CLOB;

    FUNCTION table_exists(p_table_name IN VARCHAR2) RETURN BOOLEAN IS
      l_cnt NUMBER;
    BEGIN
      SELECT COUNT(*)
        INTO l_cnt
        FROM user_tables
      WHERE table_name = UPPER(p_table_name);
      RETURN l_cnt > 0;
    END;

  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_out, TRUE);

    DBMS_LOB.APPEND(
      l_out,
        '/* APP_CONFIG seeded values exported from source environment. */' || CHR(10) ||
        '/* Adjust schema prefix (oci_focus_reports) if needed before running manually. */' || CHR(10) ||
        CHR(10)
    );

    IF NOT table_exists('APP_CONFIG') THEN
      DBMS_LOB.APPEND(l_out, '/* APP_CONFIG table not found in this schema; skipping export. */' || CHR(10));
      RETURN l_out;
    END IF;

    --------------------------------------------------------------------------
    -- Use DBMS_SQL to avoid compile-time dependency on APP_CONFIG
    --------------------------------------------------------------------------
    DECLARE
      c   INTEGER;
      rc  INTEGER;

      l_key_v  VARCHAR2(4000);
      l_val_c  CLOB;
    BEGIN
      c := DBMS_SQL.OPEN_CURSOR;

      DBMS_SQL.PARSE(
        c,
        'SELECT config_key, TO_CLOB(config_value) AS config_value '||
        '  FROM app_config '||
        ' WHERE config_key IN ('||
        '''ADB_COMPUTE_COUNT_DOWN'','||
        '''ADB_COMPUTE_COUNT_UP'','||
        '''AVAILABILITY_DAYS_BACK'','||
        '''AVAILABILITY_METRICS_TABLE'','||
        '''AVAILABILITY_METRIC_GROUPS_JSON'','||
        '''AVAILABILITY_QUERY_SUFFIX'','||
        '''AVAILABILITY_RESOLUTION'','||
        '''COMPARTMENTS_TABLE'','||
        '''CREDENTIAL_NAME'','||
        '''CSV_FIELD_LIST'','||
        '''DAYS_BACK'','||
        '''EXA_MAINTENANCE_METRICS_TABLE'','||
        '''FILE_SUFFIX'','||
        '''FILTER_BY_CREATED_SINCE'','||
        '''KEY_COLUMN'','||
        '''POST_PROCS'','||
        '''POST_SUBS_PROC_1'','||
        '''POST_SUBS_PROC_2'','||
        '''PREFIX_BASE'','||
        '''PREFIX_FILE'','||
        '''RESOURCES_TABLE'','||
        '''RESOURCE_OKE_RELATIONSHIPS_PROC'','||
        '''RESOURCE_RELATIONSHIPS_PROC'','||
        '''STAGE_TABLE'','||
        '''SUBSCRIPTIONS_TARGET_TABLE'','||
        '''SUBSCRIPTION_COMMIT_TARGET_TABLE'','||
        '''TARGET_TABLE'','||
        '''USE_DYNAMIC_PREFIX'''||
        ') '||
        ' ORDER BY config_key',
        DBMS_SQL.NATIVE
      );

      DBMS_SQL.DEFINE_COLUMN(c, 1, l_key_v, 4000);
      DBMS_SQL.DEFINE_COLUMN(c, 2, l_val_c);

      rc := DBMS_SQL.EXECUTE(c);

      WHILE DBMS_SQL.FETCH_ROWS(c) > 0 LOOP
        DBMS_SQL.COLUMN_VALUE(c, 1, l_key_v);
        DBMS_SQL.COLUMN_VALUE(c, 2, l_val_c);

        l_expr := NULL;

        IF l_val_c IS NULL THEN
          l_expr := 'CAST(NULL AS VARCHAR2(32767))';
        ELSE
          -- Build a `'...'||'...'` expression to avoid 4k literal limits
          DECLARE
            l_pos   PLS_INTEGER := 1;
            l_chunk VARCHAR2(2000);
          BEGIN
            WHILE l_pos <= DBMS_LOB.getlength(l_val_c) LOOP
              l_chunk := DBMS_LOB.SUBSTR(l_val_c, 2000, l_pos);
              l_chunk := REPLACE(l_chunk, '''', '''''');
              IF l_expr IS NULL THEN
                l_expr := '''' || l_chunk || '''';
              ELSE
                l_expr := l_expr || '||''' || l_chunk || '''';
              END IF;
              l_pos := l_pos + 2000;
            END LOOP;
          END;
        END IF;

        DBMS_LOB.APPEND(
          l_out,
            'MERGE INTO app_config c' || CHR(10) ||
            'USING (SELECT ''' ||
                REPLACE(l_key_v, '''', '''''') || ''' config_key, ' ||
                NVL(l_expr, 'CAST(NULL AS VARCHAR2(32767))') ||
                ' config_value FROM dual) s' || CHR(10) ||
            'ON (c.config_key = s.config_key)' || CHR(10) ||
            'WHEN MATCHED THEN UPDATE SET c.config_value = s.config_value, c.updated_at = SYSDATE' || CHR(10) ||
            'WHEN NOT MATCHED THEN INSERT (config_key, config_value, updated_at)' || CHR(10) ||
            'VALUES (s.config_key, s.config_value, SYSDATE);' || CHR(10) || CHR(10)
        );
      END LOOP;

      DBMS_SQL.CLOSE_CURSOR(c);
    EXCEPTION
      WHEN OTHERS THEN
        IF DBMS_SQL.IS_OPEN(c) THEN
          DBMS_SQL.CLOSE_CURSOR(c);
        END IF;
        DBMS_LOB.APPEND(l_out, '/* WARN: export_app_config failed: '||SQLERRM||' */' || CHR(10));
    END;

    RETURN l_out;
  END;

  ----------------------------------------------------------------------------
  -- CHATBOT_* seed export
  ----------------------------------------------------------------------------
  FUNCTION export_chatbot_seed RETURN CLOB IS
    l_out     CLOB := EMPTY_CLOB();

    --------------------------------------------------------------------------
    -- Quoting helpers (same semantics as your current ones)
    --------------------------------------------------------------------------
    FUNCTION q(v VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
      IF v IS NULL THEN
        RETURN 'NULL';
      ELSE
        RETURN 'q''~' || REPLACE(v, '~', '~~') || '~''';
      END IF;
    END;

    FUNCTION q_clob(c CLOB) RETURN VARCHAR2 IS
      l_v VARCHAR2(32767);
    BEGIN
      IF c IS NULL THEN
        RETURN 'NULL';
      ELSE
        l_v := DBMS_LOB.SUBSTR(c, 32767, 1);
        RETURN 'TO_CLOB(q''~' || REPLACE(l_v, '~', '~~') || '~'')';
      END IF;
    END;

    FUNCTION q_ts(p_ts TIMESTAMP) RETURN VARCHAR2 IS
    BEGIN
      IF p_ts IS NULL THEN
        RETURN 'NULL';
      ELSE
        RETURN 'TO_TIMESTAMP(''' ||
              TO_CHAR(p_ts, 'YYYY-MM-DD HH24:MI:SS.FF6') ||
              ''',''YYYY-MM-DD HH24:MI:SS.FF6'')';
      END IF;
    END;

    FUNCTION table_exists(p_table_name IN VARCHAR2) RETURN BOOLEAN IS
      l_cnt NUMBER;
    BEGIN
      SELECT COUNT(*)
        INTO l_cnt
        FROM user_tables
      WHERE table_name = UPPER(p_table_name);
      RETURN l_cnt > 0;
    END;

    PROCEDURE append(p IN VARCHAR2) IS
    BEGIN
      DBMS_LOB.APPEND(l_out, p);
    END;

    PROCEDURE append_line(p IN VARCHAR2) IS
    BEGIN
      DBMS_LOB.APPEND(l_out, p || CHR(10));
    END;

  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_out, TRUE);

    append_line('/* Seed data for CHATBOT_* tables exported from source environment. */');
    append_line('/* Tables: CHATBOT_PARAMETERS, CHATBOT_PARAMETER_COMPONENT, CHATBOT_GLOSSARY_RULES, CHATBOT_GLOSSARY_KEYWORDS */');
    append_line('');

    --------------------------------------------------------------------------
    -- 1) CHATBOT_PARAMETERS
    --------------------------------------------------------------------------
    append_line('/* CHATBOT_PARAMETERS */');
    append_line('');

    IF NOT table_exists('CHATBOT_PARAMETERS') THEN
      append_line('/* CHATBOT_PARAMETERS not found; skipping. */');
      append_line('');
    ELSE
      DECLARE
        c     INTEGER;
        rc    INTEGER;

        v_id  NUMBER;
        v_ct  VARCHAR2(4000);
        v_co  CLOB;
        v_ac  VARCHAR2(10);
        v_ds  VARCHAR2(4000);
        v_ca  TIMESTAMP;
        v_en  VARCHAR2(4000);
      BEGIN
        c := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(
          c,
          'SELECT id, component_type, content, active, dataset, created_at, environment '||
          '  FROM chatbot_parameters '||
          ' ORDER BY id',
          DBMS_SQL.NATIVE
        );

        DBMS_SQL.DEFINE_COLUMN(c, 1, v_id);
        DBMS_SQL.DEFINE_COLUMN(c, 2, v_ct, 4000);
        DBMS_SQL.DEFINE_COLUMN(c, 3, v_co); -- CLOB
        DBMS_SQL.DEFINE_COLUMN(c, 4, v_ac, 10);
        DBMS_SQL.DEFINE_COLUMN(c, 5, v_ds, 4000);
        DBMS_SQL.DEFINE_COLUMN(c, 6, v_ca);
        DBMS_SQL.DEFINE_COLUMN(c, 7, v_en, 4000);

        rc := DBMS_SQL.EXECUTE(c);

        WHILE DBMS_SQL.FETCH_ROWS(c) > 0 LOOP
          DBMS_SQL.COLUMN_VALUE(c, 1, v_id);
          DBMS_SQL.COLUMN_VALUE(c, 2, v_ct);
          DBMS_SQL.COLUMN_VALUE(c, 3, v_co);
          DBMS_SQL.COLUMN_VALUE(c, 4, v_ac);
          DBMS_SQL.COLUMN_VALUE(c, 5, v_ds);
          DBMS_SQL.COLUMN_VALUE(c, 6, v_ca);
          DBMS_SQL.COLUMN_VALUE(c, 7, v_en);

          append(
            'MERGE INTO CHATBOT_PARAMETERS t' || CHR(10) ||
            'USING (' || CHR(10) ||
            '  SELECT ' || TO_CHAR(v_id) || ' AS ID,' || CHR(10) ||
            '         ' || q(v_ct)       || ' AS COMPONENT_TYPE,' || CHR(10) ||
            '         ' || q_clob(v_co)  || ' AS CONTENT,' || CHR(10) ||
            '         ' || q(v_ac)       || ' AS ACTIVE,' || CHR(10) ||
            '         ' || q(v_ds)       || ' AS DATASET,' || CHR(10) ||
            '         ' || q_ts(v_ca)    || ' AS CREATED_AT,' || CHR(10) ||
            '         ' || q(v_en)       || ' AS ENVIRONMENT' || CHR(10) ||
            '  FROM dual' || CHR(10) ||
            ') s' || CHR(10) ||
            'ON (t.ID = s.ID)' || CHR(10) ||
            'WHEN MATCHED THEN UPDATE SET' || CHR(10) ||
            '  t.COMPONENT_TYPE = s.COMPONENT_TYPE,' || CHR(10) ||
            '  t.CONTENT        = s.CONTENT,' || CHR(10) ||
            '  t.ACTIVE         = s.ACTIVE,' || CHR(10) ||
            '  t.DATASET        = s.DATASET,' || CHR(10) ||
            '  t.CREATED_AT     = s.CREATED_AT,' || CHR(10) ||
            '  t.ENVIRONMENT    = s.ENVIRONMENT' || CHR(10) ||
            'WHEN NOT MATCHED THEN INSERT (' || CHR(10) ||
            '  ID, COMPONENT_TYPE, CONTENT, ACTIVE, DATASET, CREATED_AT, ENVIRONMENT' || CHR(10) ||
            ') VALUES (' || CHR(10) ||
            '  s.ID, s.COMPONENT_TYPE, s.CONTENT, s.ACTIVE, s.DATASET, s.CREATED_AT, s.ENVIRONMENT' || CHR(10) ||
            ');' || CHR(10) || CHR(10)
          );
        END LOOP;

        DBMS_SQL.CLOSE_CURSOR(c);
      EXCEPTION
        WHEN OTHERS THEN
          IF DBMS_SQL.IS_OPEN(c) THEN DBMS_SQL.CLOSE_CURSOR(c); END IF;
          append_line('/* WARN: export CHATBOT_PARAMETERS failed: '||SQLERRM||' */');
          append_line('');
      END;
    END IF;

    --------------------------------------------------------------------------
    -- 2) CHATBOT_PARAMETER_COMPONENT
    --------------------------------------------------------------------------
    append_line('/* CHATBOT_PARAMETER_COMPONENT */');
    append_line('');

    IF NOT table_exists('CHATBOT_PARAMETER_COMPONENT') THEN
      append_line('/* CHATBOT_PARAMETER_COMPONENT not found; skipping. */');
      append_line('');
    ELSE
      DECLARE
        c     INTEGER;
        rc    INTEGER;

        v_ct  VARCHAR2(4000);
      BEGIN
        c := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(
          c,
          'SELECT component_type FROM chatbot_parameter_component ORDER BY component_type',
          DBMS_SQL.NATIVE
        );

        DBMS_SQL.DEFINE_COLUMN(c, 1, v_ct, 4000);

        rc := DBMS_SQL.EXECUTE(c);

        WHILE DBMS_SQL.FETCH_ROWS(c) > 0 LOOP
          DBMS_SQL.COLUMN_VALUE(c, 1, v_ct);

          append(
            'MERGE INTO CHATBOT_PARAMETER_COMPONENT t' || CHR(10) ||
            'USING (' || CHR(10) ||
            '  SELECT ' || q(v_ct) || ' AS COMPONENT_TYPE' || CHR(10) ||
            '  FROM dual' || CHR(10) ||
            ') s' || CHR(10) ||
            'ON (t.COMPONENT_TYPE = s.COMPONENT_TYPE)' || CHR(10) ||
            'WHEN NOT MATCHED THEN INSERT (' || CHR(10) ||
            '  COMPONENT_TYPE' || CHR(10) ||
            ') VALUES (' || CHR(10) ||
            '  s.COMPONENT_TYPE' || CHR(10) ||
            ');' || CHR(10) || CHR(10)
          );
        END LOOP;

        DBMS_SQL.CLOSE_CURSOR(c);
      EXCEPTION
        WHEN OTHERS THEN
          IF DBMS_SQL.IS_OPEN(c) THEN DBMS_SQL.CLOSE_CURSOR(c); END IF;
          append_line('/* WARN: export CHATBOT_PARAMETER_COMPONENT failed: '||SQLERRM||' */');
          append_line('');
      END;
    END IF;

    --------------------------------------------------------------------------
    -- 3) CHATBOT_GLOSSARY_RULES
    --------------------------------------------------------------------------
    append_line('/* CHATBOT_GLOSSARY_RULES */');
    append_line('');

    IF NOT table_exists('CHATBOT_GLOSSARY_RULES') THEN
      append_line('/* CHATBOT_GLOSSARY_RULES not found; skipping. */');
      append_line('');
    ELSE
      DECLARE
        c     INTEGER;
        rc    INTEGER;

        v_id        NUMBER;
        v_dataset   VARCHAR2(4000);
        v_env       VARCHAR2(4000);
        v_active    VARCHAR2(10);
        v_match     VARCHAR2(4000);
        v_role      VARCHAR2(4000);
        v_priority  NUMBER;
        v_desc      VARCHAR2(4000);
        v_ttable    VARCHAR2(4000);
        v_tcol      VARCHAR2(4000);
        v_trole     VARCHAR2(4000);
        v_tfilter   CLOB;
        v_frule     CLOB;
        v_createdat TIMESTAMP;
        v_createdby VARCHAR2(4000);
        v_updatedat TIMESTAMP;
        v_updatedby VARCHAR2(4000);
      BEGIN
        c := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(
          c,
          'SELECT id, dataset, environment, active, match_mode, role, priority, description,'||
          '       target_table, target_column, target_role, target_filter, filter_rule,'||
          '       created_at, created_by, updated_at, updated_by '||
          '  FROM chatbot_glossary_rules '||
          ' ORDER BY id',
          DBMS_SQL.NATIVE
        );

        DBMS_SQL.DEFINE_COLUMN(c,  1, v_id);
        DBMS_SQL.DEFINE_COLUMN(c,  2, v_dataset, 4000);
        DBMS_SQL.DEFINE_COLUMN(c,  3, v_env, 4000);
        DBMS_SQL.DEFINE_COLUMN(c,  4, v_active, 10);
        DBMS_SQL.DEFINE_COLUMN(c,  5, v_match, 4000);
        DBMS_SQL.DEFINE_COLUMN(c,  6, v_role, 4000);
        DBMS_SQL.DEFINE_COLUMN(c,  7, v_priority);
        DBMS_SQL.DEFINE_COLUMN(c,  8, v_desc, 4000);
        DBMS_SQL.DEFINE_COLUMN(c,  9, v_ttable, 4000);
        DBMS_SQL.DEFINE_COLUMN(c, 10, v_tcol, 4000);
        DBMS_SQL.DEFINE_COLUMN(c, 11, v_trole, 4000);
        DBMS_SQL.DEFINE_COLUMN(c, 12, v_tfilter); -- CLOB
        DBMS_SQL.DEFINE_COLUMN(c, 13, v_frule);   -- CLOB
        DBMS_SQL.DEFINE_COLUMN(c, 14, v_createdat);
        DBMS_SQL.DEFINE_COLUMN(c, 15, v_createdby, 4000);
        DBMS_SQL.DEFINE_COLUMN(c, 16, v_updatedat);
        DBMS_SQL.DEFINE_COLUMN(c, 17, v_updatedby, 4000);

        rc := DBMS_SQL.EXECUTE(c);

        WHILE DBMS_SQL.FETCH_ROWS(c) > 0 LOOP
          DBMS_SQL.COLUMN_VALUE(c,  1, v_id);
          DBMS_SQL.COLUMN_VALUE(c,  2, v_dataset);
          DBMS_SQL.COLUMN_VALUE(c,  3, v_env);
          DBMS_SQL.COLUMN_VALUE(c,  4, v_active);
          DBMS_SQL.COLUMN_VALUE(c,  5, v_match);
          DBMS_SQL.COLUMN_VALUE(c,  6, v_role);
          DBMS_SQL.COLUMN_VALUE(c,  7, v_priority);
          DBMS_SQL.COLUMN_VALUE(c,  8, v_desc);
          DBMS_SQL.COLUMN_VALUE(c,  9, v_ttable);
          DBMS_SQL.COLUMN_VALUE(c, 10, v_tcol);
          DBMS_SQL.COLUMN_VALUE(c, 11, v_trole);
          DBMS_SQL.COLUMN_VALUE(c, 12, v_tfilter);
          DBMS_SQL.COLUMN_VALUE(c, 13, v_frule);
          DBMS_SQL.COLUMN_VALUE(c, 14, v_createdat);
          DBMS_SQL.COLUMN_VALUE(c, 15, v_createdby);
          DBMS_SQL.COLUMN_VALUE(c, 16, v_updatedat);
          DBMS_SQL.COLUMN_VALUE(c, 17, v_updatedby);

          append(
            'MERGE INTO CHATBOT_GLOSSARY_RULES t' || CHR(10) ||
            'USING (' || CHR(10) ||
            '  SELECT ' || TO_CHAR(v_id)         || ' AS ID,' || CHR(10) ||
            '         ' || q(v_dataset)          || ' AS DATASET,' || CHR(10) ||
            '         ' || q(v_env)              || ' AS ENVIRONMENT,' || CHR(10) ||
            '         ' || q(v_active)           || ' AS ACTIVE,' || CHR(10) ||
            '         ' || q(v_match)            || ' AS MATCH_MODE,' || CHR(10) ||
            '         ' || q(v_role)             || ' AS ROLE,' || CHR(10) ||
            '         ' || NVL(TO_CHAR(v_priority),'NULL') || ' AS PRIORITY,' || CHR(10) ||
            '         ' || q(v_desc)             || ' AS DESCRIPTION,' || CHR(10) ||
            '         ' || q(v_ttable)           || ' AS TARGET_TABLE,' || CHR(10) ||
            '         ' || q(v_tcol)             || ' AS TARGET_COLUMN,' || CHR(10) ||
            '         ' || q(v_trole)            || ' AS TARGET_ROLE,' || CHR(10) ||
            '         ' || q_clob(v_tfilter)     || ' AS TARGET_FILTER,' || CHR(10) ||
            '         ' || q_clob(v_frule)       || ' AS FILTER_RULE,' || CHR(10) ||
            '         ' || q_ts(v_createdat)     || ' AS CREATED_AT,' || CHR(10) ||
            '         ' || q(v_createdby)        || ' AS CREATED_BY,' || CHR(10) ||
            '         ' || q_ts(v_updatedat)     || ' AS UPDATED_AT,' || CHR(10) ||
            '         ' || q(v_updatedby)        || ' AS UPDATED_BY' || CHR(10) ||
            '  FROM dual' || CHR(10) ||
            ') s' || CHR(10) ||
            'ON (t.ID = s.ID)' || CHR(10) ||
            'WHEN MATCHED THEN UPDATE SET' || CHR(10) ||
            '  t.DATASET       = s.DATASET,' || CHR(10) ||
            '  t.ENVIRONMENT   = s.ENVIRONMENT,' || CHR(10) ||
            '  t.ACTIVE        = s.ACTIVE,' || CHR(10) ||
            '  t.MATCH_MODE    = s.MATCH_MODE,' || CHR(10) ||
            '  t.ROLE          = s.ROLE,' || CHR(10) ||
            '  t.PRIORITY      = s.PRIORITY,' || CHR(10) ||
            '  t.DESCRIPTION   = s.DESCRIPTION,' || CHR(10) ||
            '  t.TARGET_TABLE  = s.TARGET_TABLE,' || CHR(10) ||
            '  t.TARGET_COLUMN = s.TARGET_COLUMN,' || CHR(10) ||
            '  t.TARGET_ROLE   = s.TARGET_ROLE,' || CHR(10) ||
            '  t.TARGET_FILTER = s.TARGET_FILTER,' || CHR(10) ||
            '  t.FILTER_RULE   = s.FILTER_RULE,' || CHR(10) ||
            '  t.CREATED_AT    = s.CREATED_AT,' || CHR(10) ||
            '  t.CREATED_BY    = s.CREATED_BY,' || CHR(10) ||
            '  t.UPDATED_AT    = s.UPDATED_AT,' || CHR(10) ||
            '  t.UPDATED_BY    = s.UPDATED_BY' || CHR(10) ||
            'WHEN NOT MATCHED THEN INSERT (' || CHR(10) ||
            '  ID, DATASET, ENVIRONMENT, ACTIVE, MATCH_MODE, ROLE, PRIORITY, DESCRIPTION,' || CHR(10) ||
            '  TARGET_TABLE, TARGET_COLUMN, TARGET_ROLE, TARGET_FILTER, FILTER_RULE,' || CHR(10) ||
            '  CREATED_AT, CREATED_BY, UPDATED_AT, UPDATED_BY' || CHR(10) ||
            ') VALUES (' || CHR(10) ||
            '  s.ID, s.DATASET, s.ENVIRONMENT, s.ACTIVE, s.MATCH_MODE, s.ROLE, s.PRIORITY, s.DESCRIPTION,' || CHR(10) ||
            '  s.TARGET_TABLE, s.TARGET_COLUMN, s.TARGET_ROLE, s.TARGET_FILTER, s.FILTER_RULE,' || CHR(10) ||
            '  s.CREATED_AT, s.CREATED_BY, s.UPDATED_AT, s.UPDATED_BY' || CHR(10) ||
            ');' || CHR(10) || CHR(10)
          );
        END LOOP;

        DBMS_SQL.CLOSE_CURSOR(c);
      EXCEPTION
        WHEN OTHERS THEN
          IF DBMS_SQL.IS_OPEN(c) THEN DBMS_SQL.CLOSE_CURSOR(c); END IF;
          append_line('/* WARN: export CHATBOT_GLOSSARY_RULES failed: '||SQLERRM||' */');
          append_line('');
      END;
    END IF;

    --------------------------------------------------------------------------
    -- 4) CHATBOT_GLOSSARY_KEYWORDS
    --------------------------------------------------------------------------
    append_line('/* CHATBOT_GLOSSARY_KEYWORDS */');
    append_line('');

    IF NOT table_exists('CHATBOT_GLOSSARY_KEYWORDS') THEN
      append_line('/* CHATBOT_GLOSSARY_KEYWORDS not found; skipping. */');
      append_line('');
    ELSIF NOT table_exists('CHATBOT_GLOSSARY_RULES') THEN
      append_line('/* CHATBOT_GLOSSARY_RULES missing; cannot apply exclusion rule; skipping keywords export. */');
      append_line('');
    ELSE
      DECLARE
        c       INTEGER;
        rc      INTEGER;

        v_rule  NUMBER;
        v_ord   NUMBER;
        v_kw    VARCHAR2(4000);
      BEGIN
        c := DBMS_SQL.OPEN_CURSOR;

        DBMS_SQL.PARSE(
          c,
          'SELECT k.rule_id, k.ord, k.keyword '||
          '  FROM chatbot_glossary_keywords k '||
          ' WHERE NOT EXISTS ('||
          '   SELECT 1 FROM chatbot_glossary_rules gr '||
          '    WHERE gr.id = k.rule_id '||
          '      AND LOWER(gr.description) = ''workload name target filter'' '||
          ' ) '||
          ' ORDER BY k.rule_id, k.ord',
          DBMS_SQL.NATIVE
        );

        DBMS_SQL.DEFINE_COLUMN(c, 1, v_rule);
        DBMS_SQL.DEFINE_COLUMN(c, 2, v_ord);
        DBMS_SQL.DEFINE_COLUMN(c, 3, v_kw, 4000);

        rc := DBMS_SQL.EXECUTE(c);

        WHILE DBMS_SQL.FETCH_ROWS(c) > 0 LOOP
          DBMS_SQL.COLUMN_VALUE(c, 1, v_rule);
          DBMS_SQL.COLUMN_VALUE(c, 2, v_ord);
          DBMS_SQL.COLUMN_VALUE(c, 3, v_kw);

          append(
            'MERGE INTO CHATBOT_GLOSSARY_KEYWORDS t' || CHR(10) ||
            'USING (' || CHR(10) ||
            '  SELECT ' || TO_CHAR(v_rule) || ' AS RULE_ID,' || CHR(10) ||
            '         ' || TO_CHAR(v_ord)  || ' AS ORD,' || CHR(10) ||
            '         ' || q(v_kw)         || ' AS KEYWORD' || CHR(10) ||
            '  FROM dual' || CHR(10) ||
            ') s' || CHR(10) ||
            'ON (t.RULE_ID = s.RULE_ID AND t.ORD = s.ORD)' || CHR(10) ||
            'WHEN MATCHED THEN UPDATE SET' || CHR(10) ||
            '  t.KEYWORD = s.KEYWORD' || CHR(10) ||
            'WHEN NOT MATCHED THEN INSERT (' || CHR(10) ||
            '  RULE_ID, ORD, KEYWORD' || CHR(10) ||
            ') VALUES (' || CHR(10) ||
            '  s.RULE_ID, s.ORD, s.KEYWORD' || CHR(10) ||
            ');' || CHR(10) || CHR(10)
          );
        END LOOP;

        DBMS_SQL.CLOSE_CURSOR(c);
      EXCEPTION
        WHEN OTHERS THEN
          IF DBMS_SQL.IS_OPEN(c) THEN DBMS_SQL.CLOSE_CURSOR(c); END IF;
          append_line('/* WARN: export CHATBOT_GLOSSARY_KEYWORDS failed: '||SQLERRM||' */');
          append_line('');
      END;
    END IF;

    RETURN l_out;
  END;

  FUNCTION ensure_or_replace(p_ddl CLOB) RETURN CLOB IS
    l CLOB := p_ddl;
  BEGIN
    l := REGEXP_REPLACE(l, '^\s*CREATE\s+PACKAGE\s+BODY\s+', 'CREATE OR REPLACE PACKAGE BODY ', 1, 1, 'i');
    l := REGEXP_REPLACE(l, '^\s*CREATE\s+PACKAGE\s+',       'CREATE OR REPLACE PACKAGE ',      1, 1, 'i');
    l := REGEXP_REPLACE(l, '^\s*CREATE\s+PROCEDURE\s+',     'CREATE OR REPLACE PROCEDURE ',    1, 1, 'i');
    l := REGEXP_REPLACE(l, '^\s*CREATE\s+FUNCTION\s+',      'CREATE OR REPLACE FUNCTION ',     1, 1, 'i');
    l := REGEXP_REPLACE(l, '^\s*CREATE\s+TRIGGER\s+',       'CREATE OR REPLACE TRIGGER ',      1, 1, 'i');
    l := REGEXP_REPLACE(l, '^\s*CREATE\s+VIEW\s+',          'CREATE OR REPLACE VIEW ',         1, 1, 'i');
    RETURN l;
  END;

  FUNCTION wrap_create_if_missing(
    p_object_type IN VARCHAR2,
    p_object_name IN VARCHAR2,
    p_ddl         IN CLOB
  ) RETURN CLOB IS
    l_out CLOB;
    l_q   CLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_out, TRUE);

    -- escape q-quote delimiter ~
    l_q := REPLACE(p_ddl, '~', '~~');

    DBMS_LOB.APPEND(l_out,
      'DECLARE'||CHR(10)||
      '  l_cnt NUMBER;'||CHR(10)||
      'BEGIN'||CHR(10)
    );

    IF UPPER(p_object_type) = 'TABLE' THEN
      DBMS_LOB.APPEND(l_out,
        '  SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = '''||UPPER(p_object_name)||''';'||CHR(10)
      );
    ELSIF UPPER(p_object_type) = 'SEQUENCE' THEN
      DBMS_LOB.APPEND(l_out,
        '  SELECT COUNT(*) INTO l_cnt FROM user_sequences WHERE sequence_name = '''||UPPER(p_object_name)||''';'||CHR(10)
      );
    ELSIF UPPER(p_object_type) = 'INDEX' THEN
      DBMS_LOB.APPEND(l_out,
        '  SELECT COUNT(*) INTO l_cnt FROM user_indexes WHERE index_name = '''||UPPER(p_object_name)||''';'||CHR(10)
      );
    ELSE
      DBMS_LOB.APPEND(l_out, '  l_cnt := 0;'||CHR(10));
    END IF;

    DBMS_LOB.APPEND(l_out,
      '  IF l_cnt = 0 THEN'||CHR(10)||
      '    EXECUTE IMMEDIATE q''~'||l_q||'~'';'||CHR(10)||
      '  END IF;'||CHR(10)||
      'END;'||CHR(10)||'/'||CHR(10)||CHR(10)
    );

    RETURN l_out;
  END;

  FUNCTION is_excluded_table(p_table_name VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN
        p_table_name LIKE 'SDW$ERR$_%'
      OR p_table_name LIKE 'BKP\_%' ESCAPE '\'
      OR p_table_name LIKE 'BIN$%'       -- recycle bin safety
      OR p_table_name LIKE 'APEX$_%'
      OR p_table_name LIKE 'COPY$%'         -- Oracle auto COPY$ tables
      OR p_table_name LIKE 'VALIDATE$%';    -- Oracle auto VALIDATE$ tables
  END;

  

  FUNCTION has_iseq_default(p_txt IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN p_txt IS NOT NULL AND REGEXP_LIKE(p_txt, 'ISEQ\$\$_', 'i');
  END;
  FUNCTION wrap_add_column_if_missing(
    p_table_name  IN VARCHAR2,
    p_column_name IN VARCHAR2,
    p_col_ddl     IN VARCHAR2
  ) RETURN CLOB IS
    l_out CLOB;
    l_q   VARCHAR2(32767) := REPLACE(p_col_ddl, '~', '~~');
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_out, TRUE);

    DBMS_LOB.APPEND(l_out,
      'DECLARE'||CHR(10)||
      '  l_cnt NUMBER;'||CHR(10)||
      'BEGIN'||CHR(10)||
      '  SELECT COUNT(*) INTO l_cnt FROM user_tab_cols'||CHR(10)||
      '   WHERE table_name = '''||UPPER(p_table_name)||''''||CHR(10)||
      '     AND column_name = '''||UPPER(p_column_name)||''''||CHR(10)||
      '     AND hidden_column = ''NO'';'||CHR(10)||
      '  IF l_cnt = 0 THEN'||CHR(10)||
      '    EXECUTE IMMEDIATE q''~ALTER TABLE '||UPPER(p_table_name)||
            ' ADD ('||l_q||')~'';'||CHR(10)||
      '  END IF;'||CHR(10)||
      'END;'||CHR(10)||'/'||CHR(10)||CHR(10)
    );

    RETURN l_out;
  END;

  FUNCTION col_def(p_table VARCHAR2, p_col VARCHAR2) RETURN VARCHAR2 IS
    r user_tab_cols%ROWTYPE;
    l_type VARCHAR2(4000);
    l_def  VARCHAR2(32767);
  BEGIN
    SELECT *
      INTO r
      FROM user_tab_cols
    WHERE table_name = UPPER(p_table)
      AND column_name = UPPER(p_col)
      AND hidden_column = 'NO';

    -- datatype
    IF r.data_type IN ('VARCHAR2','CHAR','NCHAR','NVARCHAR2') THEN
      IF r.char_used = 'C' THEN
        l_type := r.data_type||'('||r.char_length||' CHAR)';
      ELSE
        l_type := r.data_type||'('||r.data_length||')';
      END IF;
    ELSIF r.data_type = 'NUMBER' THEN
      IF r.data_precision IS NULL THEN
        l_type := 'NUMBER';
      ELSIF r.data_scale IS NULL THEN
        l_type := 'NUMBER('||r.data_precision||')';
      ELSE
        l_type := 'NUMBER('||r.data_precision||','||r.data_scale||')';
      END IF;
    ELSE
      l_type := r.data_type;
    END IF;

    l_def := r.column_name||' '||l_type;

    -- default (best-effort; may include newline)
    IF r.data_default IS NOT NULL THEN
      l_def := l_def||' DEFAULT '||RTRIM(REPLACE(r.data_default, CHR(10), ' '));

      -- Remove identity-internal default (e.g. "SCHEMA"."ISEQ$$_nnn".nextval)
      l_def := REGEXP_REPLACE(
                l_def,
                '\s+DEFAULT\s+("?[A-Z0-9_$#]+"?\.)?"?ISEQ\$\$_[0-9]+"?\s*\.\s*NEXTVAL',
                '',
                1, 0, 'i'
              );
    END IF;

    -- nullability
    IF r.nullable = 'N' THEN
      l_def := l_def||' NOT NULL';
    END IF;

    RETURN l_def;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END;

  FUNCTION is_excluded_object(p_object_type VARCHAR2, p_object_name VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN (UPPER(p_object_name) IN ('DEPLOY_MGR_PKG'));
  END;

  ------------------------------------------------------------------------------
  -- Build Manifest Helper
  ------------------------------------------------------------------------------
  FUNCTION build_migrations_manifest RETURN CLOB IS
    l_out CLOB;
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_out, TRUE);

    FOR r IN (
      SELECT migration_id
        FROM deploy_migration_scripts
      WHERE active = 'Y'
      ORDER BY migration_id
    ) LOOP
      DBMS_LOB.APPEND(l_out, r.migration_id || CHR(10));
    END LOOP;

    RETURN l_out;
  END;

  ------------------------------------------------------------------------------
  -- Build DDL script groups (single schema)
  ------------------------------------------------------------------------------
  FUNCTION export_group(p_group IN VARCHAR2) RETURN CLOB IS
    l_out CLOB := EMPTY_CLOB();
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_out, TRUE);

    IF p_group = '01_tables' THEN
    -- Ensure TABLE ddl is a SINGLE statement (no constraints / ref constraints)
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'CONSTRAINTS', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'REF_CONSTRAINTS', FALSE);

    FOR t IN (
      SELECT table_name
      FROM user_tables
      ORDER BY table_name
    ) LOOP
      IF is_excluded_table(t.table_name) THEN
        CONTINUE;
      END IF;

      DBMS_LOB.APPEND(l_out,
        wrap_create_if_missing('TABLE', t.table_name, get_ddl_safe('TABLE', t.table_name))
      );
    END LOOP;

    -- Restore defaults for other exports
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'CONSTRAINTS', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'REF_CONSTRAINTS', TRUE);

    ELSIF p_group = '02_sequences' THEN
      FOR s IN (
        SELECT sequence_name
        FROM user_sequences
        WHERE sequence_name NOT LIKE 'ISEQ$$%'
        ORDER BY sequence_name
      ) LOOP
        DBMS_LOB.APPEND(l_out,
          wrap_create_if_missing('SEQUENCE', s.sequence_name, get_ddl_safe('SEQUENCE', s.sequence_name))
        );
      END LOOP;

    ELSIF p_group = '03_constraints' THEN
      FOR c IN (
        SELECT c.constraint_name, c.table_name, c.constraint_type
          FROM user_constraints c
        WHERE c.constraint_type IN ('P','U','C','R')
          AND c.generated = 'USER NAME'
        ORDER BY
          CASE c.constraint_type WHEN 'P' THEN 1 WHEN 'U' THEN 2 WHEN 'C' THEN 3 WHEN 'R' THEN 4 ELSE 9 END,
          c.table_name, c.constraint_name
      ) LOOP
        IF is_excluded_table(c.table_name) THEN
          CONTINUE;
        END IF;

        DECLARE
          l_ddl  CLOB;
          l_q    CLOB;
          l_type VARCHAR2(30);
        BEGIN
          l_type := CASE WHEN c.constraint_type = 'R' THEN 'REF_CONSTRAINT' ELSE 'CONSTRAINT' END;
          l_ddl  := get_ddl_safe(l_type, c.constraint_name);

          -- If GET_DDL failed, do NOT emit an executable block
          IF l_ddl IS NULL OR REGEXP_LIKE(l_ddl, '^\s*/\*\s*FAILED\s+GET_DDL', 'i') THEN
            DBMS_LOB.APPEND(l_out,
              '/* SKIP '||l_type||' '||c.constraint_name||' : GET_DDL failed */' || CHR(10) ||
              NVL(l_ddl, '/* (null ddl) */') || CHR(10) || CHR(10)
            );
            CONTINUE;
          END IF;

          -- for constraints only: remove trailing ENABLE/DISABLE tokens
          l_ddl := REGEXP_REPLACE(l_ddl, '\s+(ENABLE|DISABLE)\s*;', ';', 1, 0, 'in');
          l_ddl := REGEXP_REPLACE(l_ddl, '\s+(ENABLE|DISABLE)\s*$',  '', 1, 0, 'in');

          -- remove USING INDEX... from PK/UK so constraints don't depend on index creation order
          IF c.constraint_type IN ('P','U') THEN
            l_ddl := REGEXP_REPLACE(
                      l_ddl,
                      '\s+USING\s+INDEX\b[\s\S]*?(?=;)',
                      '',
                      1, 1, 'in'
                    );
          END IF;

          l_q := REPLACE(l_ddl, '~', '~~');

          DBMS_LOB.APPEND(l_out,
            'DECLARE'||CHR(10)||
            '  l_cnt NUMBER;'||CHR(10)||
            'BEGIN'||CHR(10)||
            '  SELECT COUNT(*) INTO l_cnt FROM user_constraints WHERE constraint_name = '''||c.constraint_name||''';'||CHR(10)||
            '  IF l_cnt = 0 THEN'||CHR(10)||
            '    EXECUTE IMMEDIATE q''~'||l_q||'~'';'||CHR(10)||
            '  END IF;'||CHR(10)||
            'END;'||CHR(10)||'/'||CHR(10)||CHR(10)
          );
        END;
      END LOOP;

    ELSIF p_group = '03a_views' THEN
      FOR v IN (
        SELECT view_name
          FROM user_views
        ORDER BY view_name
      ) LOOP
        IF is_excluded_table(v.view_name) THEN
          CONTINUE;
        END IF;

        -- CREATE OR REPLACE VIEW is fine whether it exists or not
        DBMS_LOB.APPEND(l_out, ensure_or_replace(get_ddl_safe('VIEW', v.view_name)) || CHR(10));
      END LOOP;

    ELSIF p_group = '04_pkg_specs' THEN
      FOR p IN (SELECT object_name FROM user_objects WHERE object_type='PACKAGE' ORDER BY object_name) LOOP
        IF is_excluded_object('PACKAGE', p.object_name) THEN
          CONTINUE;
        END IF;
        DBMS_LOB.APPEND(l_out, ensure_or_replace(get_ddl_safe('PACKAGE', p.object_name)) || CHR(10));
      END LOOP;

    ELSIF p_group = '06_pkg_bodies' THEN
      FOR p IN (SELECT object_name FROM user_objects WHERE object_type='PACKAGE BODY' ORDER BY object_name) LOOP
        IF is_excluded_object('PACKAGE BODY', p.object_name) THEN
          CONTINUE;
        END IF;
        DBMS_LOB.APPEND(l_out, ensure_or_replace(get_ddl_safe('PACKAGE_BODY', p.object_name)) || CHR(10));
      END LOOP;


    ELSIF p_group = '07_procs_funcs' THEN
      FOR o IN (
        SELECT object_type, object_name
        FROM user_objects
        WHERE object_type IN ('PROCEDURE','FUNCTION')
        ORDER BY object_type, object_name
      ) LOOP
        IF is_excluded_object(o.object_type, o.object_name) THEN
          CONTINUE;
        END IF;
        DBMS_LOB.APPEND(l_out, ensure_or_replace(get_ddl_safe(o.object_type, o.object_name)) || CHR(10));
      END LOOP;


    ELSIF p_group = '08_mviews' THEN
      FOR v IN (SELECT mview_name AS name FROM user_mviews ORDER BY mview_name) LOOP

        -- Drop MV and (if still present) its storage table with the same name
        DBMS_LOB.APPEND(l_out,
          'DECLARE'||CHR(10)||
          '  l_mv  NUMBER;'||CHR(10)||
          '  l_tab NUMBER;'||CHR(10)||
          'BEGIN'||CHR(10)||
          '  SELECT COUNT(*) INTO l_mv FROM user_mviews WHERE mview_name = '''||v.name||''';'||CHR(10)||
          '  IF l_mv > 0 THEN'||CHR(10)||
          '    EXECUTE IMMEDIATE ''DROP MATERIALIZED VIEW '||v.name||''';'||CHR(10)||
          '  END IF;'||CHR(10)||
          ''||CHR(10)||
          '  -- If the MV storage table still exists, drop it so CREATE MV can reuse the name'||CHR(10)||
          '  SELECT COUNT(*) INTO l_tab FROM user_tables WHERE table_name = '''||v.name||''';'||CHR(10)||
          '  IF l_tab > 0 THEN'||CHR(10)||
          '    EXECUTE IMMEDIATE ''DROP TABLE '||v.name||' PURGE'';'||CHR(10)||
          '  END IF;'||CHR(10)||
          'END;'||CHR(10)||
          '/'||CHR(10)||CHR(10)
        );

        -- Create: ensure it's one SQL statement (strip trailing SQLTERMINATOR ;)
        DECLARE
          l_ddl CLOB;
        BEGIN
          l_ddl := get_ddl_safe('MATERIALIZED_VIEW', v.name);

          -- make it a single SQL statement terminated by ;
          l_ddl := REGEXP_REPLACE(l_ddl, ';\s*$', '', 1, 1);

          DBMS_LOB.APPEND(l_out, l_ddl || ';' || CHR(10) || CHR(10));
        END;

      END LOOP;

    ELSIF p_group = '09_triggers' THEN
      FOR tr IN (
        SELECT trigger_name
          FROM user_triggers
        ORDER BY trigger_name
      ) LOOP
        -- optional: skip system/auto triggers if you want (usually none in user_triggers)
        DBMS_LOB.APPEND(l_out,
          ensure_or_replace(get_ddl_safe('TRIGGER', tr.trigger_name)) || CHR(10)
        );
      END LOOP;

    ELSIF p_group = '10_indexes' THEN
      FOR i IN (
        SELECT index_name
        FROM user_indexes
        WHERE generated = 'N'
          AND index_name NOT LIKE 'SYS\_%' ESCAPE '\'
        ORDER BY index_name
      ) LOOP
        DBMS_LOB.APPEND(l_out,
          wrap_create_if_missing('INDEX', i.index_name, get_ddl_safe('INDEX', i.index_name))
        );
      END LOOP;

    ELSIF p_group = '01a_table_alters' THEN
      FOR c IN (
        SELECT c.table_name, c.column_name
          FROM user_tab_cols c
          JOIN user_tables   t
            ON t.table_name = c.table_name
        WHERE c.hidden_column  = 'NO'
          AND c.virtual_column = 'NO'
        ORDER BY c.table_name, c.column_id
      ) LOOP
        IF is_excluded_table(c.table_name) THEN
          CONTINUE;
        END IF;
        DECLARE
          l_col VARCHAR2(32767);
        BEGIN
          l_col := col_def(c.table_name, c.column_name);
          -- Skip any column DDL still referencing ISEQ$$ (safety net)
          IF l_col IS NOT NULL AND NOT has_iseq_default(l_col) THEN
            DBMS_LOB.APPEND(l_out,
              wrap_add_column_if_missing(c.table_name, c.column_name, l_col)
            );
          END IF;
        END;
      END LOOP;

    ELSE
      DBMS_LOB.APPEND(l_out, '/* unknown group '||p_group||' */'||CHR(10));
    END IF;

    RETURN l_out;
  END;

  ------------------------------------------------------------------------------
  -- Export APEX application
  ------------------------------------------------------------------------------
  FUNCTION export_apex_app(p_app_id IN NUMBER) RETURN CLOB IS
    l_files apex_t_export_files;
  BEGIN
    l_files := apex_export.get_application(p_application_id => p_app_id);
    -- Most cases: first file is the app export SQL.
    RETURN l_files(1).contents;
  END;

  ------------------------------------------------------------------------------
  FUNCTION get_latest_bundle_id(p_app_id IN NUMBER) RETURN NUMBER IS
    l_id NUMBER;
  BEGIN
    SELECT bundle_id
      INTO l_id
      FROM (
        SELECT bundle_id
          FROM deploy_bundles
         WHERE app_id = p_app_id
         ORDER BY created_at DESC
      )
     WHERE ROWNUM = 1;
    RETURN l_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END;

  ------------------------------------------------------------------------------
  FUNCTION export_bundle(
    p_app_id       IN NUMBER,
    p_version_tag  IN VARCHAR2,
    p_include_jobs IN BOOLEAN DEFAULT TRUE
  ) RETURN NUMBER IS
    l_run_id    NUMBER;
    l_bundle_id NUMBER;
    l_zip       BLOB;
    l_manifest  CLOB;
    l_apex_clob CLOB;
    l_tmp       CLOB;
  BEGIN
    l_run_id := run_start('EXPORT');
    run_log(l_run_id, 'Export bundle start. app_id='||p_app_id||' version='||p_version_tag);

    md_setup;

    -- IMPORTANT:
    -- No non-autonomous DML must happen before this call.
    l_apex_clob := export_apex_app(p_app_id);

    -- IMPORTANT:
    -- End the export transaction (APEX export uses SET TRANSACTION).
    COMMIT;

    run_log(l_run_id, 'APEX export done.');

    -- Now it is safe to do normal DML and build the zip/bundle

    DBMS_LOB.CREATETEMPORARY(l_manifest, TRUE);
    DBMS_LOB.APPEND(l_manifest,
      '{'||
      '"app_id":'||TO_CHAR(p_app_id)||','||
      '"version":"'||REPLACE(p_version_tag,'"','\"')||'",'||
      '"schema":"'||USER||'",'||
      '"created_at":"'||TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM')||'",'||
      '"notes":"Credentials are not exported; ensure required credentials exist per environment."'||
      '}'
    );

    -- Build zip
    DBMS_LOB.CREATETEMPORARY(l_zip, TRUE);

    -- Add manifest.json
    APEX_ZIP.ADD_FILE(l_zip, 'manifest.json', clob_to_blob(l_manifest));

    -- Add APEX app export
    APEX_ZIP.ADD_FILE(l_zip, 'apex/f1200.sql', clob_to_blob(l_apex_clob));

    -- DB groups (deterministic order)
    l_tmp := export_group('01_tables');      APEX_ZIP.ADD_FILE(l_zip,'db/ddl/01_tables.sql',      clob_to_blob(l_tmp));
    l_tmp := export_group('01a_table_alters');APEX_ZIP.ADD_FILE(l_zip,'db/ddl/01a_table_alters.sql', clob_to_blob(l_tmp));
    l_tmp := export_group('02_sequences');   APEX_ZIP.ADD_FILE(l_zip,'db/ddl/02_sequences.sql',   clob_to_blob(l_tmp));
    l_tmp := export_group('03_constraints'); APEX_ZIP.ADD_FILE(l_zip,'db/ddl/03_constraints.sql', clob_to_blob(l_tmp));
    l_tmp := export_group('03a_views');      APEX_ZIP.ADD_FILE(l_zip,'db/ddl/03a_views.sql',      clob_to_blob(l_tmp));
    l_tmp := export_group('04_pkg_specs');   APEX_ZIP.ADD_FILE(l_zip,'db/ddl/04_pkg_specs.sql',   clob_to_blob(l_tmp));
    l_tmp := export_contexts;                APEX_ZIP.ADD_FILE(l_zip,'db/ddl/05_contexts.sql',    clob_to_blob(l_tmp));
    l_tmp := export_group('06_pkg_bodies');  APEX_ZIP.ADD_FILE(l_zip,'db/ddl/06_pkg_bodies.sql',  clob_to_blob(l_tmp));
    l_tmp := export_group('07_procs_funcs'); APEX_ZIP.ADD_FILE(l_zip,'db/ddl/07_procs_funcs.sql', clob_to_blob(l_tmp));
    l_tmp := export_group('08_mviews');      APEX_ZIP.ADD_FILE(l_zip,'db/ddl/08_mviews.sql',      clob_to_blob(l_tmp));
    l_tmp := export_group('09_triggers');    APEX_ZIP.ADD_FILE(l_zip,'db/ddl/09_triggers.sql',    clob_to_blob(l_tmp));
    l_tmp := export_group('10_indexes');     APEX_ZIP.ADD_FILE(l_zip,'db/ddl/10_indexes.sql',     clob_to_blob(l_tmp));

    -- Migrations
    l_tmp := build_migrations_manifest;
    APEX_ZIP.ADD_FILE(l_zip, 'db/migrations/manifest.txt', clob_to_blob(l_tmp));

    FOR r IN (
      SELECT migration_id, script_clob
        FROM deploy_migration_scripts
      WHERE active = 'Y'
      ORDER BY migration_id
    ) LOOP
      APEX_ZIP.ADD_FILE(l_zip, 'db/migrations/'||r.migration_id, clob_to_blob(r.script_clob));
    END LOOP;

    -- APP_CONFIG seed (selected keys)
    l_tmp := export_app_config;
    APEX_ZIP.ADD_FILE(l_zip, 'db/ddl/95_app_config.sql', clob_to_blob(l_tmp));

    -- CHATBOT_* seed (parameters, components, glossary rules/keywords)
    l_tmp := export_chatbot_seed;
    APEX_ZIP.ADD_FILE(l_zip, 'db/ddl/96_chatbot_seed.sql', clob_to_blob(l_tmp));

    -- Scheduler Jobs
    IF p_include_jobs THEN
      l_tmp := export_jobs;
      APEX_ZIP.ADD_FILE(l_zip,'db/ddl/90_jobs.sql', clob_to_blob(l_tmp));
    END IF;

    APEX_ZIP.FINISH(l_zip);
    run_log(l_run_id, 'ZIP built.');

    INSERT INTO deploy_bundles(app_id, version_tag, manifest_json, bundle_zip)
    VALUES (p_app_id, p_version_tag, l_manifest, l_zip)
    RETURNING bundle_id INTO l_bundle_id;

    run_log(l_run_id, 'Bundle stored. bundle_id='||l_bundle_id);
    run_ok(l_run_id);
    COMMIT;
    RETURN l_bundle_id;

  EXCEPTION
    WHEN OTHERS THEN
      run_fail(l_run_id, DBMS_UTILITY.FORMAT_ERROR_STACK||CHR(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      COMMIT;
      RAISE;
  END;

  ------------------------------------------------------------------------------
  -- Script runner: executes a SQL/PLSQL script text containing:
  --   - SQL statements ending with ;
  --   - PL/SQL blocks terminated by a line containing only /
  --   - Ignores SQL*Plus directives: PROMPT, SET, SPOOL, WHENEVER, etc.
  ------------------------------------------------------------------------------
  PROCEDURE run_sql_script(
    p_run_id     IN NUMBER,
    p_script     IN CLOB,
    p_script_name IN VARCHAR2,
    p_dry_run     IN BOOLEAN DEFAULT FALSE
  ) IS
    l_len        PLS_INTEGER := DBMS_LOB.GETLENGTH(p_script);
    l_pos        PLS_INTEGER := 1;

    l_line       VARCHAR2(32767);
    l_nl         PLS_INTEGER;

    l_stmt       CLOB;
    l_in_plsql   BOOLEAN := FALSE;
    l_in_block_comment BOOLEAN := FALSE;

    PROCEDURE stmt_reset IS
    BEGIN
      IF l_stmt IS NOT NULL THEN
        DBMS_LOB.FREETEMPORARY(l_stmt);
      END IF;
      DBMS_LOB.CREATETEMPORARY(l_stmt, TRUE);
    END;

    PROCEDURE stmt_append(p_txt IN VARCHAR2) IS
    BEGIN
      IF l_stmt IS NULL THEN
        DBMS_LOB.CREATETEMPORARY(l_stmt, TRUE);
      END IF;
      DBMS_LOB.APPEND(l_stmt, p_txt || CHR(10));
    END;

    FUNCTION trim_line(p IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
      RETURN TRIM(REPLACE(REPLACE(p, CHR(13), ''), CHR(10), ''));
    END;

    FUNCTION is_ignored_directive(p IN VARCHAR2) RETURN BOOLEAN IS
      t VARCHAR2(32767) := UPPER(LTRIM(p));
    BEGIN
      RETURN t LIKE 'PROMPT %'
          OR t LIKE 'SET %'
          OR t LIKE 'SPOOL %'
          OR t LIKE 'WHENEVER %'
          OR t LIKE 'COLUMN %'
          OR t LIKE 'COL %'
          OR t LIKE 'BREAK %'
          OR t LIKE 'TTITLE %'
          OR t LIKE 'BTITLE %'
          OR t = 'EXIT'
          OR t = 'QUIT';
    END;

    FUNCTION is_plsql_start(p IN VARCHAR2) RETURN BOOLEAN IS
      t VARCHAR2(32767) := UPPER(LTRIM(p));
    BEGIN
      RETURN t LIKE 'DECLARE%'
          OR t LIKE 'BEGIN%'
          OR t LIKE 'CREATE%PACKAGE%'
          OR t LIKE 'CREATE%PROCEDURE%'
          OR t LIKE 'CREATE%FUNCTION%'
          OR t LIKE 'CREATE%TRIGGER%';
    END;

    PROCEDURE exec_stmt(p_kind IN VARCHAR2) IS
    BEGIN
      IF l_stmt IS NULL OR DBMS_LOB.GETLENGTH(l_stmt) = 0 THEN
        RETURN;
      END IF;

      IF p_dry_run THEN
        run_log(p_run_id, 'DRY-RUN: would execute '||p_kind||' from '||p_script_name||
                          ' (len='||DBMS_LOB.GETLENGTH(l_stmt)||')');
        stmt_reset;
        RETURN;
      END IF;

      run_log(p_run_id, 'Executing '||p_kind||' from '||p_script_name);

      BEGIN
        EXECUTE IMMEDIATE l_stmt;
      EXCEPTION
        WHEN OTHERS THEN
          -- Allow invalid compilation units to exist
          IF SQLCODE IN (-24344, -6550) THEN
            run_log(
              p_run_id,
              'COMPILE WARNING in '||p_script_name||': '||SQLERRM
            );
            -- do NOT raise
          ELSE
            run_log(
              p_run_id,
              'FAILED in '||p_script_name||' ('||p_kind||'): '||SQLERRM||CHR(10)||
              'SQL(first 1000)='||DBMS_LOB.SUBSTR(l_stmt, 1000, 1)
            );
            RAISE;
          END IF;
      END;

      stmt_reset;
    END;

  BEGIN
    stmt_reset;
    run_log(p_run_id, 'Run script: '||p_script_name||' len='||l_len);

    WHILE l_pos <= l_len LOOP
      l_nl := DBMS_LOB.INSTR(p_script, CHR(10), l_pos);

      IF l_nl = 0 THEN
        l_line := DBMS_LOB.SUBSTR(p_script, LEAST(32767, l_len - l_pos + 1), l_pos);
        l_pos := l_len + 1;
      ELSE
        l_line := DBMS_LOB.SUBSTR(p_script, LEAST(32767, l_nl - l_pos), l_pos);
        l_pos := l_nl + 1;
      END IF;

      -- Normalize
      l_line := REPLACE(l_line, CHR(13), '');

      -- Handle /* ... */ block comments correctly
      IF l_in_block_comment THEN
        stmt_append(l_line);
        IF INSTR(l_line, '*/') > 0 THEN
          l_in_block_comment := FALSE;
        END IF;
        CONTINUE;
      END IF;

      IF INSTR(l_line, '/*') > 0 AND INSTR(l_line, '*/') = 0 THEN
        l_in_block_comment := TRUE;
        stmt_append(l_line);
        CONTINUE;
      END IF;

      -- Skip truly empty lines
      IF trim_line(l_line) IS NULL THEN
        CONTINUE;
      END IF;

      -- Preserve single-line comments
      IF REGEXP_LIKE(LTRIM(l_line), '^--') THEN
        stmt_append(l_line);
        CONTINUE;
      END IF;

      -- Ignore SQL*Plus directives only outside PL/SQL units/blocks
      IF NOT l_in_plsql AND is_ignored_directive(l_line) THEN
        CONTINUE;
      END IF;

      -- "/" on its own line ends a PL/SQL unit/block
      IF trim_line(l_line) = '/' THEN
        exec_stmt('PLSQL_BLOCK');
        l_in_plsql := FALSE;
        CONTINUE;
      END IF;

      -- Start-of-unit heuristic
      IF NOT l_in_plsql AND is_plsql_start(l_line) THEN
        l_in_plsql := TRUE;
      END IF;

      stmt_append(l_line);

      -- For pure SQL statements (not PL/SQL), treat trailing ";" as terminator
      IF NOT l_in_plsql THEN
        IF REGEXP_LIKE(trim_line(l_line), ';\s*$') THEN
          exec_stmt('SQL');
        END IF;
      END IF;

    END LOOP;

    -- Flush any remaining statement
    IF l_stmt IS NOT NULL AND DBMS_LOB.GETLENGTH(l_stmt) > 0 THEN
      -- If it's leftover without "/", try to execute (common for single SQL ending with ;)
      exec_stmt(CASE WHEN l_in_plsql THEN 'PLSQL_BLOCK_EOF' ELSE 'SQL_EOF' END);
    END IF;

  END run_sql_script;

  ------------------------------------------------------------------------------
  -- Public wrapper: execute a CLOB script under deploy logging
  -- Intended for APEX uploads (manual SQL, e.g. deploy_mgr_pkg updates).
  ------------------------------------------------------------------------------
  PROCEDURE exec_script_clob(
    p_script      IN CLOB,
    p_script_name IN VARCHAR2,
    p_dry_run     IN BOOLEAN DEFAULT FALSE
  ) IS
    l_run_id NUMBER;
  BEGIN
    l_run_id := run_start('MANUAL_SQL');
    run_log(l_run_id,
      'Manual exec_script_clob: '||p_script_name||
      ' dry_run='||CASE WHEN p_dry_run THEN 'Y' ELSE 'N' END
    );

    run_sql_script(
      p_run_id      => l_run_id,
      p_script      => p_script,
      p_script_name => p_script_name,
      p_dry_run     => p_dry_run
    );

    run_ok(l_run_id);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      run_fail(
        l_run_id,
        DBMS_UTILITY.FORMAT_ERROR_STACK||CHR(10)||
        DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
      );
      COMMIT;
      RAISE;
  END exec_script_clob;

  ------------------------------------------------------------------------------

  PROCEDURE run_script_from_zip(
    p_run_id  IN NUMBER,
    p_zip     IN BLOB,
    p_path    IN VARCHAR2,
    p_dry_run IN BOOLEAN DEFAULT FALSE
  ) IS
    l_blob BLOB;
    l_clob CLOB;
  BEGIN
    IF p_zip IS NULL OR DBMS_LOB.getlength(p_zip) = 0 THEN
      raise_application_error(-20000, 'Bundle ZIP is NULL/empty for '||p_path);
    END IF;

    BEGIN
      l_blob := APEX_ZIP.GET_FILE_CONTENT(
                  p_zipped_blob => p_zip,
                  p_file_name   => p_path
                );
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        run_log(p_run_id, 'Missing file in zip: '||p_path||' (skipping)');
        RETURN;
    END;

    IF l_blob IS NULL OR DBMS_LOB.getlength(l_blob) = 0 THEN
      run_log(p_run_id, 'Empty file in zip: '||p_path||' (skipping)');
      RETURN;
    END IF;

    l_clob := blob_to_clob(l_blob);

    IF l_clob IS NULL OR DBMS_LOB.getlength(l_clob) = 0 THEN
      run_log(p_run_id, 'Converted CLOB empty for: '||p_path||' (skipping)');
      RETURN;
    END IF;

    run_sql_script(
      p_run_id      => p_run_id,
      p_script      => l_clob,
      p_script_name => p_path,
      p_dry_run     => p_dry_run
    );
  END;

  PROCEDURE ensure_migration_registry(p_run_id IN NUMBER, p_dry_run IN BOOLEAN) IS
  BEGIN
    IF p_dry_run THEN
      run_log(p_run_id, 'DRY-RUN: would ensure DEPLOY_SCHEMA_MIGRATIONS exists');
      RETURN;
    END IF;

    BEGIN
      EXECUTE IMMEDIATE q'[
        CREATE TABLE deploy_schema_migrations (
          migration_id VARCHAR2(200) PRIMARY KEY,
          applied_at   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
          applied_by   VARCHAR2(128) DEFAULT USER NOT NULL,
          bundle_id    NUMBER,
          notes        VARCHAR2(4000)
        )
      ]';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -955 THEN RAISE; END IF;
    END;
  END;

  FUNCTION zip_file_to_clob(p_zip BLOB, p_path VARCHAR2) RETURN CLOB IS
    l_blob BLOB;
  BEGIN
    l_blob := APEX_ZIP.GET_FILE_CONTENT(
                p_zipped_blob => p_zip,
                p_file_name   => p_path
              );
    RETURN blob_to_clob(l_blob);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  PROCEDURE apply_migrations(
    p_run_id    IN NUMBER,
    p_bundle_id IN NUMBER,
    p_zip       IN BLOB,
    p_dry_run   IN BOOLEAN
  ) IS
    l_manifest CLOB;
    l_pos      PLS_INTEGER := 1;
    l_line     VARCHAR2(4000);
    l_exists   NUMBER;

    FUNCTION next_line(p CLOB, p_pos IN OUT PLS_INTEGER) RETURN VARCHAR2 IS
      l_len   PLS_INTEGER;
      l_nl    PLS_INTEGER;
      l_txt   VARCHAR2(4000);
    BEGIN
      IF p IS NULL THEN RETURN NULL; END IF;
      l_len := DBMS_LOB.GETLENGTH(p);
      IF p_pos > l_len THEN RETURN NULL; END IF;

      l_nl := DBMS_LOB.INSTR(p, CHR(10), p_pos);
      IF l_nl = 0 THEN
        l_txt := DBMS_LOB.SUBSTR(p, LEAST(4000, l_len - p_pos + 1), p_pos);
        p_pos := l_len + 1;
      ELSE
        l_txt := DBMS_LOB.SUBSTR(p, LEAST(4000, l_nl - p_pos), p_pos);
        p_pos := l_nl + 1;
      END IF;

      l_txt := TRIM(REPLACE(l_txt, CHR(13), ''));
      RETURN l_txt;
    END;
  BEGIN
    ensure_migration_registry(p_run_id => p_run_id, p_dry_run => p_dry_run);

    l_manifest := zip_file_to_clob(p_zip, 'db/migrations/manifest.txt');

    IF l_manifest IS NULL OR DBMS_LOB.GETLENGTH(l_manifest) = 0 THEN
      run_log(p_run_id, 'No migrations manifest found. Skipping migrations.');
      RETURN;
    END IF;

    run_log(p_run_id, 'Migrations: reading db/migrations/manifest.txt');

    LOOP
      l_line := next_line(l_manifest, l_pos);
      EXIT WHEN l_line IS NULL;

      -- skip blanks/comments
      IF l_line IS NULL OR l_line = '' OR SUBSTR(l_line,1,1) = '#' THEN
        CONTINUE;
      END IF;

      IF p_dry_run THEN
        l_exists := 0; -- don't query the registry in dry-run
      ELSE
        SELECT COUNT(*) INTO l_exists
        FROM deploy_schema_migrations
        WHERE migration_id = l_line;
      END IF;

      IF l_exists > 0 THEN
        run_log(p_run_id, 'Migration already applied: '||l_line);
        CONTINUE;
      END IF;

      IF p_dry_run THEN
        run_log(p_run_id, 'DRY-RUN: would apply migration '||l_line);
      ELSE
        run_log(p_run_id, 'Applying migration: '||l_line);

        run_script_from_zip(p_run_id, p_zip, 'db/migrations/'||l_line, p_dry_run => p_dry_run);

        INSERT INTO deploy_schema_migrations(migration_id, applied_at, applied_by, bundle_id, notes)
        VALUES (l_line, SYSTIMESTAMP, USER, p_bundle_id, NULL);

        COMMIT;

        run_log(p_run_id, 'Applied migration OK: '||l_line);
      END IF;
    END LOOP;

    run_log(p_run_id, 'Migrations complete.');
  END;

  PROCEDURE deploy_bundle_internal(
    p_run_id            IN NUMBER,
    p_bundle_id         IN NUMBER,
    p_enable_jobs_after IN BOOLEAN,
    p_dry_run           IN BOOLEAN,
    p_install_mode      IN VARCHAR2 DEFAULT 'UPDATE'
  ) IS
    l_zip BLOB;
  BEGIN
    run_log(p_run_id,
      'whoami: session_user='||SYS_CONTEXT('USERENV','SESSION_USER')||
      ' current_user='||SYS_CONTEXT('USERENV','CURRENT_USER')||
      ' current_schema='||SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
    );

    SELECT bundle_zip
      INTO l_zip
      FROM deploy_bundles
    WHERE bundle_id = p_bundle_id
    FOR UPDATE;

    run_log(p_run_id, 'Deploy start. bundle_id='||p_bundle_id||
                      ' dry_run='||CASE WHEN p_dry_run THEN 'Y' ELSE 'N' END);

    IF p_dry_run THEN
      run_log(p_run_id, 'DRY-RUN MODE: no statements must execute (DDL/DML).');
    END IF;

    run_script_from_zip(p_run_id, l_zip, 'db/ddl/01_tables.sql',        p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/01a_table_alters.sql', p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/02_sequences.sql',     p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/10_indexes.sql',  p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/03_constraints.sql',   p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/03a_views.sql',   p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/04_pkg_specs.sql',     p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/05_contexts.sql',      p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/06_pkg_bodies.sql',    p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/07_procs_funcs.sql',   p_dry_run => p_dry_run);

    apply_migrations(
      p_run_id    => p_run_id,
      p_bundle_id => p_bundle_id,
      p_zip       => l_zip,
      p_dry_run   => p_dry_run
    );

    run_script_from_zip(p_run_id, l_zip, 'db/ddl/08_mviews.sql',   p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/09_triggers.sql', p_dry_run => p_dry_run);
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/90_jobs.sql',     p_dry_run => p_dry_run);

    -- Seed APP_CONFIG for selected keys
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/95_app_config.sql', p_dry_run => p_dry_run);

    -- Seed CHATBOT_* tables (parameters, components, glossary)
    run_script_from_zip(p_run_id, l_zip, 'db/ddl/96_chatbot_seed.sql', p_dry_run => p_dry_run);

    IF NOT p_dry_run AND p_enable_jobs_after THEN
      run_log(p_run_id,
        'NOTE: p_enable_jobs_after=TRUE but global enable is now disabled; ' ||
        'job enabled/disabled state is controlled per job by export_jobs.');
    END IF;


    IF NOT p_dry_run THEN
      --------------------------------------------------------------------
      -- Read desired scheme from APP_CONFIG (target-owned)
      --------------------------------------------------------------------
      DECLARE
        l_ws_name   VARCHAR2(255);
        l_app_id    NUMBER;
        l_ws_id     NUMBER;
        l_offset    NUMBER;
        l_off       NUMBER;
        l_mode      VARCHAR2(10);
      BEGIN
        resolve_apex_target(p_run_id, l_ws_name, l_app_id);

        l_ws_name := TRIM(l_ws_name);

        run_log(p_run_id, 'APEX target: workspace="'||l_ws_name||'", app_id='||l_app_id);

        l_ws_id := apex_util.find_security_group_id(p_workspace => l_ws_name);

        l_offset := get_app_offset(p_run_id, l_ws_name, l_app_id); -- number, default 0

        run_log(p_run_id, 'APEX resolved workspace_id='||NVL(TO_CHAR(l_ws_id),'NULL'));

        IF l_ws_id IS NULL OR l_ws_id = 0 THEN
          raise_application_error(
            -20030,
            'APEX workspace not found by apex_util.find_security_group_id for workspace="'||
            l_ws_name||'". Check APP_CONFIG.APEX_WORKSPACE_NAME for whitespace/mismatch.'
          );
        END IF;

        apex_util.set_security_group_id(l_ws_id);
        --apex_application_install.set_workspace_id(l_ws_id);
        --apex_application_install.set_workspace(p_workspace => l_ws_name);

        apex_application_install.set_schema(USER);
        apex_application_install.set_application_id(l_app_id);

        l_mode := UPPER(NVL(p_install_mode,'UPDATE'));

        -- Use the persisted offset (0 if none). INITIAL should have already written APP_CONFIG.APEX_ID_OFFSET_APP.
        apex_application_install.set_offset(NVL(l_offset,0));
        run_log(p_run_id, 'PRE-IMPORT: using offset='||TO_CHAR(NVL(l_offset,0))||' (mode='||l_mode||')');

        -- keep your auth scheme override logic here (if any)
      END;

      --------------------------------------------------------------------
      -- IMPORT APP
      --------------------------------------------------------------------
      run_script_from_zip(p_run_id, l_zip, 'apex/f1200.sql', p_dry_run => FALSE);

      --------------------------------------------------------------------
      -- POST-IMPORT: enforce + verify if scheme name is present
      --------------------------------------------------------------------
      DECLARE
        l_scheme_name  VARCHAR2(255);
        l_ws_id        NUMBER;
        l_app_id       NUMBER;
        l_ws_name      VARCHAR2(255);

        l_cnt          NUMBER;
        l_current      VARCHAR2(255);
        l_oidc_url     VARCHAR2(4000);
        l_disc_attr    VARCHAR2(4000);
      BEGIN
        l_scheme_name := get_app_config_value('l_auth_scheme_name');

        IF l_scheme_name IS NULL THEN
          run_log(p_run_id, 'POST-IMPORT: no l_auth_scheme_name in APP_CONFIG; skipping auth enforcement/verification.');
          RETURN;
        END IF;

        -- Resolve + set workspace context again (clean + explicit)
        resolve_apex_target(p_run_id, l_ws_name, l_app_id);

        l_ws_id := apex_util.find_security_group_id(p_workspace => l_ws_name);
        apex_util.set_security_group_id(l_ws_id);

        apex_application_install.set_schema(USER);
        apex_application_install.set_application_id(l_app_id);

        -- Guard: scheme must exist in imported app
        SELECT COUNT(*)
          INTO l_cnt
          FROM apex_application_auth
         WHERE application_id = l_app_id
           AND authentication_scheme_name = l_scheme_name;

        IF l_cnt = 0 THEN
          raise_application_error(
            -20002,
            'Auth scheme "'||l_scheme_name||'" not found in app '||l_app_id||' after import.'
          );
        END IF;

        -- Enforce active scheme (requires APEX_ADMINISTRATOR_ROLE)
        apex_application_admin.set_authentication_scheme(
          p_application_id => l_app_id,
          p_name           => l_scheme_name
        );

        -- Verify active scheme == expected (fail deployment if not)
        SELECT aa.authentication_scheme_name
          INTO l_current
          FROM apex_applications a
          JOIN apex_application_auth aa
            ON aa.application_id = a.application_id
           AND aa.authentication_scheme_id = a.authentication_scheme_id
         WHERE a.application_id = l_app_id;

        IF l_current <> l_scheme_name THEN
          raise_application_error(
            -20003,
            'Auth scheme mismatch. Expected='||l_scheme_name||' Current='||l_current
          );
        END IF;

        -- OCI SSO checks (LOG ONLY)
        IF UPPER(l_scheme_name) = UPPER('OCI SSO') THEN
          l_oidc_url := get_app_config_value('OIDC_DISCOVERY_URL');

          IF l_oidc_url IS NULL THEN
            run_log(p_run_id, 'WARN: OIDC_DISCOVERY_URL missing/NULL in APP_CONFIG. Deployment continues; may require manual config.');
          ELSE
            run_log(p_run_id, 'OIDC_DISCOVERY_URL present in APP_CONFIG.');
          END IF;

          BEGIN
            SELECT attribute_03
              INTO l_disc_attr
              FROM apex_application_auth
             WHERE application_id = l_app_id
               AND authentication_scheme_name = l_scheme_name;
          EXCEPTION
            WHEN OTHERS THEN
              l_disc_attr := NULL;
          END;

          IF l_disc_attr IS NULL THEN
            run_log(p_run_id, 'WARN: Could not read ATTRIBUTE_03 (Discovery URL) for scheme "'||l_scheme_name||'".');
          ELSIF INSTR(UPPER(l_disc_attr), '#DISCOVERY_URL#') > 0 THEN
            run_log(p_run_id, 'INFO: Auth scheme "'||l_scheme_name||'" Discovery URL uses #DISCOVERY_URL# placeholder.');
          ELSE
            run_log(
              p_run_id,
              'WARN: Auth scheme "'||l_scheme_name||'" Discovery URL is hard-coded (expected #DISCOVERY_URL#). Value starts: '||
              SUBSTR(l_disc_attr, 1, 200)
            );
          END IF;
        END IF;
      END;
    END IF;

    IF p_dry_run THEN
      run_log(p_run_id, 'DRY-RUN: skipping compile_schema and deploy_applied insert.');
      run_ok(p_run_id);
      COMMIT;
    ELSE
      DBMS_UTILITY.COMPILE_SCHEMA(schema => USER, compile_all => FALSE);
      BEGIN
        EXECUTE IMMEDIATE 'ALTER PACKAGE DEPLOY_MGR_PKG COMPILE';
        EXECUTE IMMEDIATE 'ALTER PACKAGE DEPLOY_MGR_PKG COMPILE BODY';
      EXCEPTION
        WHEN OTHERS THEN
          NULL; -- don’t fail deploy due to deploy manager recompilation
      END;


      INSERT INTO deploy_applied(bundle_id, result, details)
      VALUES (p_bundle_id, 'SUCCESS', 'Deployed bundle '||p_bundle_id);

      run_ok(p_run_id);
      COMMIT;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      IF NOT p_dry_run THEN
        INSERT INTO deploy_applied(bundle_id, result, details)
        VALUES (p_bundle_id, 'FAILED',
                DBMS_UTILITY.FORMAT_ERROR_STACK||CHR(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      END IF;

      run_fail(p_run_id, DBMS_UTILITY.FORMAT_ERROR_STACK||CHR(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      COMMIT;
      RAISE;
  END;

  -- Job for deploy bundle (SQL-typed args; scheduler cannot pass BOOLEAN)
  PROCEDURE deploy_worker(
    p_run_id            IN NUMBER,
    p_bundle_id         IN NUMBER,
    p_enable_jobs_after IN VARCHAR2,  -- 'Y'/'N'
    p_dry_run           IN VARCHAR2,  -- 'Y'/'N'
    p_install_mode      IN VARCHAR2,  -- 'INITIAL'/'UPDATE'
    p_workspace_name    IN VARCHAR2,  -- required for INITIAL
    p_app_id            IN NUMBER,    -- required for INITIAL
    p_allow_overwrite   IN VARCHAR2,  -- 'Y'/'N' (INITIAL only)
    p_use_id_offset     IN VARCHAR2,  -- 'Y'/'N' (INITIAL only)
    p_auth_scheme_name  IN VARCHAR2 
  ) IS
      l_enable_jobs_after BOOLEAN := (NVL(UPPER(p_enable_jobs_after),'N') = 'Y');
      l_dry_run           BOOLEAN := (NVL(UPPER(p_dry_run),'N') = 'Y');
    
      l_mode            VARCHAR2(10) := UPPER(NVL(p_install_mode,'UPDATE'));

      l_allow_overwrite VARCHAR2(1) := UPPER(NVL(p_allow_overwrite,'N'));
  BEGIN
      run_log(p_run_id, 'Worker start (job). bundle_id='||p_bundle_id||
                        ' enable_jobs_after='||CASE WHEN l_enable_jobs_after THEN 'Y' ELSE 'N' END||
                        ' dry_run='||CASE WHEN l_dry_run THEN 'Y' ELSE 'N' END);

      

      IF l_mode = 'INITIAL' THEN
        IF p_workspace_name IS NULL OR p_app_id IS NULL THEN
          raise_application_error(-20030, 'INITIAL mode requires p_workspace_name and p_app_id.');
        END IF;
        ensure_app_config_table(p_run_id => p_run_id, p_dry_run => l_dry_run);

        -- Guard: do not overwrite an existing app id unless allowed
        IF NOT l_dry_run THEN
          DECLARE
            l_ws_id NUMBER;
            l_cnt   NUMBER;
          BEGIN
            l_ws_id := apex_util.find_security_group_id(p_workspace => p_workspace_name);
            apex_util.set_security_group_id(l_ws_id);

            SELECT COUNT(*)
              INTO l_cnt
              FROM apex_applications
            WHERE application_id = p_app_id;

            IF l_cnt > 0 AND l_allow_overwrite <> 'Y' THEN
              raise_application_error(-20031,
                'APEX app id '||p_app_id||' already exists in workspace '||p_workspace_name||
                '. Re-run with p_allow_overwrite=Y or choose a different p_app_id.');
            END IF;
          END;
        END IF;

        upsert_app_config(p_run_id, 'APEX_WORKSPACE_NAME', p_workspace_name, l_dry_run);
        upsert_app_config(p_run_id, 'APEX_APP_ID',        TO_CHAR(p_app_id), l_dry_run);
        DECLARE
          l_auth VARCHAR2(255) := NVL(p_auth_scheme_name, 'Oracle APEX Accounts');
        BEGIN
          IF l_auth NOT IN ('Oracle APEX Accounts', 'OCI SSO') THEN
            raise_application_error(-20040,
              'Invalid p_auth_scheme_name="'||l_auth||'". Allowed: "Oracle APEX Accounts" or "OCI SSO".');
          END IF;

          upsert_app_config(p_run_id, 'l_auth_scheme_name', l_auth, l_dry_run);
        END;

        -- Persist APEX component ID offset for this app copy (used for INITIAL and UPDATE imports)
        DECLARE
          l_existing_txt VARCHAR2(4000);
          l_existing     NUMBER;
          l_new          NUMBER;
          l_flag         VARCHAR2(1) := UPPER(NVL(p_use_id_offset,'N'));
        BEGIN
          l_existing_txt := get_app_config_value('APEX_ID_OFFSET_APP');

          BEGIN
            l_existing := CASE WHEN l_existing_txt IS NULL THEN 0 ELSE TO_NUMBER(TRIM(l_existing_txt)) END;
          EXCEPTION
            WHEN OTHERS THEN
              l_existing := 0;
          END;

          IF l_flag = 'Y' THEN
            -- If offset already stored, keep it (ensures future UPDATE uses the same offset)
            IF l_existing IS NULL OR l_existing = 0 THEN
              -- APEX version without apex_application_install.generate_offset: build a large unique offset
              l_new := TO_NUMBER(TO_CHAR(SYSTIMESTAMP, 'FF6')) * 1000000000000
                       + TO_NUMBER(TO_CHAR(SYSDATE, 'J'));
            ELSE
              l_new := l_existing;
            END IF;
          ELSE
            -- No offset requested; if an offset already exists, preserve it to avoid breaking future UPDATE imports
            IF l_existing IS NULL THEN
              l_new := 0;
            ELSE
              l_new := l_existing;
            END IF;
          END IF;

          upsert_app_config(p_run_id, 'APEX_ID_OFFSET_APP', TO_CHAR(NVL(l_new,0)), l_dry_run);

          run_log(p_run_id, 'APEX_ID_OFFSET_APP='||TO_CHAR(NVL(l_new,0))||' (p_use_id_offset='||l_flag||')');
        END;
      END IF;
      deploy_bundle_internal(
            p_run_id            => p_run_id,
            p_bundle_id         => p_bundle_id,
            p_enable_jobs_after => l_enable_jobs_after,
            p_dry_run           => l_dry_run,
            p_install_mode      => p_install_mode
          );

    EXCEPTION
      WHEN OTHERS THEN
        run_fail(p_run_id, DBMS_UTILITY.FORMAT_ERROR_STACK||CHR(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
  END;

  PROCEDURE enqueue_deploy(
    p_bundle_id         IN NUMBER,
    p_enable_jobs_after IN BOOLEAN DEFAULT FALSE,
    p_dry_run           IN BOOLEAN DEFAULT FALSE,
    p_install_mode      IN VARCHAR2 DEFAULT 'UPDATE', -- 'INITIAL'/'UPDATE'
    p_workspace_name    IN VARCHAR2 DEFAULT NULL,     -- only used for INITIAL
    p_app_id            IN NUMBER   DEFAULT NULL,     -- only used for INITIAL
    p_auth_scheme_name  IN VARCHAR2 DEFAULT 'Oracle APEX Accounts',
    p_allow_overwrite   IN VARCHAR2 DEFAULT 'N',      -- 'Y'/'N' (INITIAL only)
    p_use_id_offset     IN VARCHAR2 DEFAULT 'N',      -- 'Y'/'N' (INITIAL only)
    o_run_id            OUT NUMBER,
    o_job_name          OUT VARCHAR2
  ) IS
      l_job_name VARCHAR2(128);
    BEGIN
      o_run_id := run_start('DEPLOY', p_bundle_id);
      run_log(o_run_id, 'Enqueue deploy. dry_run='||CASE WHEN p_dry_run THEN 'Y' ELSE 'N' END);

      l_job_name := 'DEPLOY_'||o_run_id;

      DBMS_SCHEDULER.CREATE_JOB(
        job_name            => l_job_name,
        job_type            => 'STORED_PROCEDURE',
        job_action          => 'DEPLOY_MGR_PKG.DEPLOY_WORKER',
        number_of_arguments => 10,
        enabled             => FALSE,
        auto_drop           => TRUE
      );

      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 1, TO_CHAR(o_run_id));
      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 2, TO_CHAR(p_bundle_id));
      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 3, CASE WHEN p_enable_jobs_after THEN 'Y' ELSE 'N' END);
      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 4, CASE WHEN p_dry_run THEN 'Y' ELSE 'N' END);

      

      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 5, NVL(p_install_mode,'UPDATE'));
      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 6, p_workspace_name);
      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 7, CASE WHEN p_app_id IS NULL THEN NULL ELSE TO_CHAR(p_app_id) END);

      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 8, NVL(p_allow_overwrite,'N'));
      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 9, NVL(p_use_id_offset,'N'));
      DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(l_job_name, 10, NVL(p_auth_scheme_name,'Oracle APEX Accounts'));

      DBMS_SCHEDULER.ENABLE(l_job_name);

      o_job_name := l_job_name;
      run_log(o_run_id, 'Job submitted: '||l_job_name);

      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        IF o_run_id IS NOT NULL THEN
          run_fail(o_run_id, DBMS_UTILITY.FORMAT_ERROR_STACK||CHR(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        END IF;
      RAISE;
  END;

  PROCEDURE deploy_bundle(
    p_bundle_id         IN NUMBER,
    p_enable_jobs_after IN BOOLEAN DEFAULT FALSE,
    p_dry_run           IN BOOLEAN DEFAULT FALSE
  ) IS
    l_run_id NUMBER;
  BEGIN
    l_run_id := run_start('DEPLOY', p_bundle_id);

    deploy_bundle_internal(
      p_run_id            => l_run_id,
      p_bundle_id         => p_bundle_id,
      p_enable_jobs_after => p_enable_jobs_after,
      p_dry_run           => p_dry_run,
      p_install_mode      => 'UPDATE'
    );
  END deploy_bundle;

END deploy_mgr_pkg;
/