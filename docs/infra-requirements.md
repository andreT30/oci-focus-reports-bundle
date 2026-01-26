# Infrastructure Requirements

Home: [README](../README.md) · **Docs** · **Infrastructure Requirements**

This document lists the infrastructure prerequisites that must be in place **before** deploying the application.
Deployment steps are documented separately in [Deployment](deployment.md).

---

## Checklist (must exist)
- OCI tenancy and an admin/operator who can create IAM policies
- A dedicated OCI compartment for the solution
- Oracle Autonomous Database with Oracle APEX enabled
- IAM Dynamic Group for the Autonomous Database **Resource Principal**
- IAM policies for:
  - reading OCI cost/usage objects (where your usage reports live)
  - reading OCI resource metadata (if you enable inventory features)
  - using OCI Generative AI (for the chatbot)

---

## Oracle Autonomous Database
Minimum expectations (tune for your scale):
- ADB provisioned for analytics / batch refresh workloads
- APEX enabled in the database
- Network access aligned with your standards (public/private endpoint, allowlists, etc.)
- Database user/schema created for the application objects

---

## IAM: Dynamic Group (Resource Principal)
The application uses **Resource Principal** from Autonomous Database. No API keys, passwords, or secrets are required.

Recommended Dynamic Group name (example):

```
focus-reports-ADW-DG
```

Example matching rule (use the OCID of your Autonomous Database):

```
resource.id = 'ocid1.autonomousdatabase.oc1.eu-frankfurt-1....'
```

---

## IAM: Policies

### 1) Policy at root (or the appropriate scope)
Policy name (example):

```
focus-reports-root-policy
```

Example (usage reports tenancy/object store access). Adjust to your tenancy layout and where your usage reports are produced:

```
define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq

endorse dynamic-group focus-reports-DG to read objects in tenancy usage-report
endorse dynamic-group focus-reports-DG to read buckets in tenancy usage-report
endorse dynamic-group focus-reports-DG to read objectstorage-namespaces in tenancy usage-report
```

### 2) Policy for the solution compartment
Policy name (example):

```
focus-reports-compartment-policy
```

Example (Generative AI access). Scope this to the compartment where ADB runs:

```
Allow dynamic-group focus-reports-ADW-DG to manage generative-ai-family in compartment id ocid1.compartment.oc1....
Allow dynamic-group focus-reports-ADW-DG to manage genai-agent-family in compartment id ocid1.compartment.oc1....
```

Notes:
- Keep policies **least-privilege** and scoped to the smallest required compartment/tenancy.
- If your usage reports are generated in the same tenancy/compartment, you may not need cross-tenancy endorsements.
- If you do not enable the chatbot, you can omit the GenAI permissions.

---

## OCI Generative AI availability
The NL2SQL chatbot requires access to OCI Generative AI in a region where it is available for your tenancy.
If GenAI is not enabled/available, the rest of the analytics application can still run (dashboards, reports, ETL),
but chatbot features must be disabled in configuration.

---

## Ownership boundaries
Typical split of responsibilities:
- **Cloud/IAM admins**: compartments, networking, dynamic groups, policies
- **DB/APEX admins**: ADB provisioning, schema/users, APEX workspace/app import
- **App operators**: configuration (`APP_CONFIG`), job monitoring, backups/updates
