# Application Update (In-App)

Home: [README](../README.md) · **Docs** · **Update**

---

## Overview

Application updates are performed **entirely inside the application UI**.

Updates reuse the internal **Deployment Manager**, but:
- are triggered from the UI
- support **dry-run mode**
- support **backup before update**
- are fully logged and auditable

No external SQL scripts or manual redeployments are required for normal updates.

---

> ⚠️ **Important – Update Order Matters**
>
> Updating the **Deployment Manager** and updating the **Application Bundle**
> are **two independent tasks** and must **not** be merged.
>
> **Best practice (recommended order):**
> 1. Update the **Deployment Manager** first
> 2. Then update the **Application Bundle**
>
> The application update process depends on the Deployment Manager.
> If the Deployment Manager is outdated, application updates may fail or behave unexpectedly.
>
> See: [Updating the Deployment Manager](#updating-the-deployment-manager-advanced)

---

## Update Entry Point (UI Navigation)

Only **Administrators** can perform updates.

Navigation path:

**Login → Navigation Bar → Administration → Upload / Update App**

This page is the **single control point** for:
- application updates
- rollback preparation
- dry-run validation
- monitoring
- Deployment Manager package updates

---

## In-App Update Workflow (Recommended)

> 📸 ![In-App upload page.](/screenshots/update1.png)  

### Step 1 — Upload bundle ZIP

On the **Upload / Update App** page, upload a new application bundle ZIP.

Supported options:
- upload from local file
- provide a **direct GitHub URL** (with download button)


> Upload bundle ZIP (local file or GitHub link)

**Notes**
- The bundle ZIP is stored as-is (BLOB)
- No extraction occurs outside the database
- The bundle structure must match deployment expectations

---

### Step 2 — Backup existing application (strongly recommended)

Before proceeding, click on  **Backup!**.

This will re-direct to the app export page.

More info: 
> [Export/Backup app](/docs/backup-export.md)


---

### Step 3 — Dry-run update (validation)

Enable **Dry Run** to validate the update without applying changes.

Dry-run performs:
- bundle validation
- script ordering checks
- permission checks
- Deployment Manager logic execution
- full logging

**No persistent (db or app) changes are applied.**

Use dry-run to:
- detect errors early
- validate bundle integrity
- confirm readiness for update

---

### Step 4 — Execute update

After a successful dry-run, perform the **actual update**.

The system will:
- execute bundle scripts
- apply database changes
- import updated APEX application
- leave scheduler jobs **unchanged** unless explicitly handled


---

### Step 5 — Monitor update execution

Each update creates a **run record** with:
- run id
- status
- timestamps
- detailed execution log

Monitoring is available directly from the same page.

> Logs are printed in the large text-area on the same page. While updating the application, logging will be frozen and clicking any app tile/link will require a new login session.

---

## Rollback Model

Rollback is supported via:
- previously created **application backup**
- controlled re-application through the update workflow

Rollback operations are also:
- logged
- auditable
- deterministic

---

## Updating the Deployment Manager (Advanced)

The **Deployment Manager package** can be updated independently from the application bundle.

This is a **separate operation** and should be treated as a **prerequisite** for application updates.

---

### Why this matters

- The application update workflow **depends on the Deployment Manager**
- New bundle formats or update logic may require an updated manager
- The application cannot automatically notify users that a new Deployment Manager version exists

As a result:

> **It is best practice to always update the Deployment Manager before applying any application bundle update.**

---

### When to update the Deployment Manager

Update the Deployment Manager when:
- new update features are introduced
- fixes are applied to the update mechanism
- compatibility with new bundle versions is required

---

### How to update

The Deployment Manager is updated from the **same Update page** in the application UI.

- Upload latest deploy_manager_ddl.sql (can be downloaded from github) and click on **Run SQLUpload (Deploy Manager)**

> 📸 ![In-App upload page.](/screenshots/update2.png)  
> Deployment Manager package update option

---

### Operational guidance

- Always **backup the existing application** first
- Perform a **dry-run** before executing the update
- Monitor update logs carefully
- Only proceed with application bundle updates **after** the Deployment Manager update completes successfully

---

### Important constraints

- Deployment Manager update and application bundle update **cannot be combined**
- There is **no automatic notification mechanism** for Deployment Manager updates
- Administrators are responsible for keeping the Deployment Manager up to date

---

## Fallback: Update Manager API (Advanced / Emergency)

In rare cases (e.g. UI unavailable), updates can be triggered via the
Deployment Manager API.

This is intended for:
- controlled recovery scenarios
- operator-assisted remediation

> ⚠️ This is **not** the normal update path.

Refer to:
- [Deployment Manager API](deploy-manager-api.md)

---

## Operator Guidance (Summary)

- Use **Deployment Guide** only for first-time installs
- Use **In-App Update** for all upgrades
- Always:
  - backup first
  - dry-run before execution
  - review logs
- Never update production environments blindly

---

## Logging & Auditability

Every update:
- has a unique run id
- is fully logged
- can be reviewed post-factum
- supports compliance and audit requirements

---

**See also**
- [Deployment Guide](deployment.md)
- [Admin Guide](admin-guide.md)
- [Deployment Manager API](deploy-manager-api.md)
- [Troubleshooting](troubleshooting.md)
