# Administration & Operations

Home: [README](../README.md) · **Docs** · **Administration & Operations**

This guide is for administrators and operators after the initial deployment.
For installation, see [Deployment](deployment.md).

---

## Operating model
Most operations fall into four areas:
1. **Configuration**: maintain `APP_CONFIG` and (optionally) chatbot metadata
2. **Data freshness**: run/monitor refresh jobs
3. **Change management**: export bundles, apply updates, keep audit trails
4. **Supportability**: use logs to diagnose issues quickly

---

## Configuration management
- Primary configuration lives in `APP_CONFIG`.  
  Reference: [Application Configuration (APP_CONFIG)](app-config.md)
- Make changes via the admin UI where possible (validation + traceability).

Recommended practices:
- keep DEV/TEST/PROD configurations versioned (exported or documented)
- avoid “one-off” schema edits outside of the deployment/update mechanism

---

## Scheduler jobs
The application uses DB Scheduler jobs for ingestion and refresh workflows.

Operational guidance:
- keep jobs disabled until configuration is complete
- enable jobs gradually and confirm resource impact
- monitor job runs and failures daily (or integrate into your monitoring)

---

## Backups and rollback
Use the in-app bundle export as your primary backup artifact:
- before upgrades
- before major configuration changes
- before onboarding a new data source

See: [Backup / Export](backup-export.md)

---

## Chatbot operations (if enabled)
Operator checklist:
- confirm GenAI IAM permissions and service availability
- review chatbot parameters (limits, model settings, safety constraints)
- monitor chatbot logs for errors and unexpected SQL patterns

See: [NL2SQL Chatbot](chatbot.md)

---

## Observability
Where to look first:
- deployment runs (updates/installs)
- scheduler job logs (refresh failures)
- application logs / error tables
- chatbot execution logs

If troubleshooting, capture:
- timestamp
- run id / request id
- affected page/job name
- error text and the most recent log entries

See: [Troubleshooting](troubleshooting.md)
