# Application Backup / Export

Home: [README](../README.md) · **Docs** · **Backup / Export**

---

## Overview

The application provides a built-in **backup / export** mechanism that allows
Administrators to create a **bundle ZIP** of the currently installed application.

This bundle can be used for:
- backup and rollback
- migration to another environment
- update validation
- audit and traceability

The export process is executed **inside the application UI** and does not require
external scripts or database access.

---

## Access

Only **Administrators** can access the export functionality.

Navigation path:

**Login → Navigation Bar → Administration → Export/Download App**

---

## Export Page Overview

> 📸 ![In-App export page.](/screenshots/export1.png)  

The export page contains:

- **App Id**  
  The APEX application identifier to export (Fixed).
- **Version Tag**  
  A version label assigned to the exported bundle (Auto-assigned after export processing finishes).
- **Include Jobs**  
  When enabled, scheduler jobs are included in the bundle.
- **Export** button  
  Starts the export process.
- **Download** button  
  Appears after the export completes successfully.

---

## Export / Backup Workflow

### Step 1 — Review export settings

- Verify the **App Id**
- Decide whether to **Include Jobs**

> Including jobs is recommended for full backups.

---

### Step 2 — Start export

Click **Export**.

The application will:
- start the export process
- lock the page to prevent concurrent actions
- display a processing indicator


> 📸 ![In-App export page.](/screenshots/export2.png)


---

### Step 3 — Export processing

While processing:
- the export runs asynchronously
- progress is tracked internally
- the UI shows a loading indicator

No user action is required.

---

### Step 4 — Download bundle

When the export finishes:
- the **Download** button becomes available
- the generated **bundle ZIP** can be downloaded


> 📸 ![In-App export page.](/screenshots/export3.png) 


The downloaded ZIP represents a **complete snapshot** of the application at that point in time.

---

## What the exported bundle contains

The export bundle typically includes:

- database objects (DDL)
- application metadata
- APEX application export
- optional scheduler jobs
- manifest and version metadata

The bundle is compatible with:
- in-app update workflows
- Deployment Manager–based deployments

---

## Operational Notes

- Always create a backup **before performing an update**
- Store exported bundles securely
- Version tags should be meaningful and traceable (e.g. date/time)

---

## Security Notes

- No secrets are included in the exported bundle
- Export respects OCI IAM and application authorization
- The export process does not expose customer data in the UI

---

**See also**
- [Application Update](update.md)
- [Deployment Guide](deployment.md)
- [Admin Guide](admin-guide.md)
