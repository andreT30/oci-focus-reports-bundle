# Configuration

Home: [README](../README.md) · **Docs** · **Configuration**

## Overview
The application is configured entirely through **database tables**, primarily `APP_CONFIG`.

There are:
- no hardcoded OCIDs
- no hardcoded tag names
- no environment-specific values in code

This makes the system portable across:
- DEV / TEST / PROD
- different OCI tenancies
- different tagging conventions

---

## Configuration Principles

- Configuration is **read at runtime**
- Keys are stable; values vary by environment
- Missing or incorrect config causes visible, logged failures
- Secrets must be injected externally (never committed)

---

## APP_CONFIG Table

### Purpose
Centralized key-value configuration store.

### Typical Columns
- `CONFIG_KEY`
- `CONFIG_VALUE`
- optional description / category

---

## Configuration Categories

### 1. OCI Environment

Controls how the application connects to OCI data.

**Examples**
- root compartment identifiers
- region lists
- tenancy scope

These define **what data is visible** to the app.

---

### 2. Tag Mapping & Attribution

Defines how OCI tags are interpreted.

**Examples**
- cost center tag key
- environment tag key
- implementor / owner tag key

These values are used dynamically to extract tag data from JSON.

---

### 3. Analytics Behavior

Controls how analytics behave.

**Examples**
- default date ranges
- normalization rules
- feature toggles for dashboards

---

### 4. Chatbot Configuration

Controls NL2SQL behavior.

**Examples**
- model identifiers
- routing behavior
- execution limits
- verbosity of summaries

This allows chatbot tuning **without code changes**.

---

### 5. Application Behavior

General application settings.

**Examples**
- UI defaults
- feature flags
- environment labels

---

## Environment-Specific Values

Typical environment-specific values:
- OCI compartment OCIDs
- region lists
- tagging conventions
- enabled jobs

These should be:
- set post-deployment
- excluded or anonymized in GitHub

---

## Configuration Deployment Strategy

Recommended:
1. Deploy schema objects
2. Insert baseline config keys (no secrets)
3. Override values per environment
4. Validate via health checks

---

## Validation & Troubleshooting

Misconfiguration usually manifests as:
- empty dashboards
- chatbot returning no results
- job failures

Check:
- APP_CONFIG values
- logging tables
- job run logs

Details: [troubleshooting.md](troubleshooting.md)

**See also**
- [Admin Guide](admin-guide.md)
- [Deployment Guide](deployment.md)
