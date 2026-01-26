# Backup / Export

Home: [README](../README.md) · **Docs** · **Backup / Export**

The application provides a built-in export mechanism that produces a **bundle ZIP** representing the currently installed state.

Use exports for:
- backups and rollback safety
- migration to another environment
- validating upgrades (export before/after)
- audit and traceability

---

## What an export contains
Typically includes:
- APEX application export
- database DDL and package scripts shipped with the bundle
- required reference/config seed data for the application to run

Not included by design:
- secrets/credentials
- environment-specific OCIDs and compartment selections
- IAM policies

---

## When to export
Recommended points:
- before applying an update
- before major configuration changes
- before onboarding new data sources or changing ingestion behavior

---

## Where exports live
Exports are stored in the database as bundle BLOBs (the same mechanism used for deployment).
Your deployment may also provide a UI to download the ZIP for external storage.

---

## Related documents
- [Deployment](deployment.md)
- [Update](update.md)
- [Deployment Manager API](deploy-manager-api.md)
