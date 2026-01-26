# Application Update (In-App)

Home: [README](../README.md) · **Docs** · **Update**

Updates are performed **inside the application UI** using the internal Deployment Manager.
No external scripts are required for standard upgrades.

---

## Key concepts
- Updates are executed as **deploy runs** (auditable, logged).
- You can run in **dry-run** mode to preview changes.
- You can create a **backup/export bundle** before applying an update.
- Jobs can be left disabled during the update and enabled afterwards.

---

## Important: update order
Updating the **Deployment Manager** and updating the **application bundle** are separate activities.

Recommended order:
1. **Update the Deployment Manager** (if the release includes changes to deployment logic)
2. **Update the application bundle** (APEX app + database objects)

This minimizes the risk of an older Deployment Manager applying a newer bundle incorrectly.

---

## Standard update workflow
1. **Backup/export** the current installation (optional but recommended).  
   See [Backup / Export](backup-export.md).
2. Upload the new bundle ZIP through the in-app update page.
3. Run **Dry Run** and review the plan/logs.
4. Run the real update.
5. Validate:
   - app opens and core pages render
   - scheduler jobs are present and in the expected enabled/disabled state
   - key dashboards refresh successfully
6. Re-enable jobs (if you disabled them during the update).

---

## What is (and is not) included
Included:
- APEX application import/update
- Database objects shipped in the bundle (tables/views/packages)
- Configuration seeds and reference data shipped in the bundle

Not included by design:
- environment credentials/secrets
- environment-specific OCIDs and compartment selection
- IAM policies (managed in OCI)

---

## Where to monitor
Operational visibility:
- deployment run tables (run history and detailed logs)
- scheduler job run logs
- chatbot logs (if enabled)

See:
- [Administration & Operations](admin-guide.md)
- [Troubleshooting](troubleshooting.md)
