# Application Update (In-App)

Home: [README](../README.md) · **Docs** · **Update**

## Overview

Application updates are handled **entirely inside the application UI**.

No external scripts or direct database calls are required for normal updates.

---

## Update Characteristics

- Triggered from the application admin interface
- Uses the same Deployment Manager internally
- Supports dry-run mode
- Logs every update step

---

## Why updates are separated from deployment

- Initial deployment is an infrastructure operation
- Updates are an application-level concern
- Separation reduces risk and operational complexity

---

## Operator Guidance

- Use `docs/deployment.md` only for first-time installs
- Use the in-app update workflow for all upgrades
- Never re-run deployment scripts on an existing environment

---

## Logging & Rollback

- Each update is logged with a run id
- Failures are diagnosable via update logs
- Rollback behavior is managed inside the application

**See also**
- [Deployment Guide](deployment.md)
- [Admin Guide](admin-guide.md)
- [Troubleshooting](troubleshooting.md)
