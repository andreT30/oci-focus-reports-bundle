# Configuration

Home: [README](../README.md) · **Docs** · **Configuration**

The application is configured through database tables (primarily `APP_CONFIG`).  
No OCIDs, tag names, or environment-specific values are hardcoded in source code.

Use this document as the “what to configure” overview.  
For the full parameter reference, see [Application Configuration (APP_CONFIG)](app-config.md).

---

## Configuration layers

### 1) `APP_CONFIG` (primary)
Controls runtime behavior such as:
- tenancy/compartment scope
- cost/usage ingestion settings
- refresh cadence and date defaults
- UI feature flags
- chatbot enablement and limits

### 2) Chatbot metadata (if chatbot is enabled)
Stored in dedicated tables (glossary rules, hints, and parameters). See:
- [NL2SQL Chatbot](chatbot.md)

### 3) Scheduler jobs
Operational refresh jobs are created during deployment and can be enabled/disabled per environment. See:
- [Administration & Operations](admin-guide.md)

---

## Typical post-install configuration flow
1. Populate required `APP_CONFIG` keys (tenancy/compartment IDs, namespaces, etc.).
2. Decide whether the chatbot is enabled in this environment.
3. Enable refresh jobs (or run manual refresh once).
4. Validate dashboards and confirm data freshness.
5. Review [Security & Trust Model](security.md) and ensure IAM policies match your scope.

---

## Portability guidance
To keep environments consistent:
- treat `APP_CONFIG` as the only place for environment values
- avoid changing core views/packages unless you are maintaining a fork
- export/import bundles for upgrades instead of manual patching

---

## Related documents
- [Infrastructure Requirements](infra-requirements.md)
- [Deployment](deployment.md)
- [Application Configuration (APP_CONFIG)](app-config.md)
- [Administration & Operations](admin-guide.md)
