# Infrastructure Requirements

Home: [README](../README.md) · Docs · Infrastructure Requirements

---

## Purpose

This document defines the mandatory infrastructure prerequisites that must exist
before deploying the application.

It is intentionally separated from the deployment procedure to:
- reduce operational risk
- support security and audit reviews
- clearly define infrastructure responsibility boundaries

No deployment or update steps are described here.

---

## High-Level Requirements

Before deployment, the following must already exist:

- An existing Oracle Cloud Infrastructure (OCI) tenancy
- An existing OCI Administrator account
- A dedicated OCI compartment for the deployment
- An Autonomous Database suitable for analytics and batch processing
- OCI IAM configuration (Dynamic Groups and Policies)
- OCI GenAI service availability (for chatbot functionality)

---

## OCI Tenancy

- The application is deployed into an existing OCI tenancy
- All access control is enforced via OCI IAM
- The application uses OCI Resource Principal only
- No credentials, API keys, passwords, or secrets are used or stored

---

## OCI Administrator Account

An OCI user with administrator privileges is required to:

- create compartments
- create Autonomous Databases
- manage IAM Dynamic Groups
- create and manage IAM policies

This account is required only for initial infrastructure setup.

---

## Deployment Compartment

Create or select a dedicated OCI compartment for the deployment.

This compartment will contain:
- the Autonomous Database
- Object Storage buckets
- all application-managed resources

Make a note of the Compartment OCID.
This value is required in multiple IAM policy definitions.

---

## Autonomous Database (ADB)

### Required Database Type

Autonomous AI Lakehouse (preferred)
(formerly Autonomous Data Warehouse)

This application is designed for analytics-heavy and batch-oriented workloads.

---

### Database Version Preference

For **new Autonomous Database deployments**, **Oracle Autonomous Database 26ai**
(or the latest AI-enabled version available) is **strongly recommended**.

Reasons include:
- native JSON data type and enhanced JSON querying
- improved SQL and PL/SQL support for JSON-centric workloads
- built-in vector capabilities, enabling future enhancements
  (e.g. semantic search, embeddings, and AI-assisted analytics)
- continued alignment with Oracle’s AI-enabled database roadmap

Earlier Autonomous Database versions remain supported, but newer AI-enabled
versions provide a more future-proof foundation.

---

### Why Autonomous Database (ADB)

The application is intentionally designed to run on **Oracle Autonomous Database**.

Key reasons include:

- **Fully managed by Oracle**
  - No operating system or database patching
  - No manual backups
  - No infrastructure maintenance overhead
  - Allows teams to focus on analytics and application logic

- **DBMS_CLOUD is pre-installed and pre-configured**
  - Native access to Object Storage
  - Secure, policy-driven access to OCI services
  - No external credentials or custom integrations required

- **Seamless OCI integration**
  - Native support for OCI Resource Principal
  - Direct interaction with OCI services governed by IAM policies
  - Required by the application for:
    - cost and usage report ingestion
    - resource discovery
    - object storage access
    - Generative AI integration

This tight integration with OCI services is a **core architectural requirement**
and is not achievable with self-managed or non-autonomous databases.


---

### Database Requirements

- APEX must be enabled
- The database must run in the selected deployment compartment
- The database must support OCI Resource Principal

Make a note of the Autonomous Database OCID.
This value is required for Dynamic Group configuration.

---

## OCI IAM – Dynamic Group

Create a Dynamic Group in the Default identity domain with the following properties.

Name:
```
focus-reports-ADW-DG
```

Rule:
```
resource.id = 'ocid1.autonomousdatabase.oc1.eu-frankfurt-1....'
```

Replace the OCID above with the Autonomous Database OCID created earlier.

This Dynamic Group represents the Autonomous Database identity
when using OCI Resource Principal.

---

## OCI IAM – Root Compartment Policy

Create a tenancy-level (root compartment) IAM policy.

Name:
```
focus-reports-root-policy
```

---

Policy Rules:

```
define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq

endorse dynamic-group focus-reports-DG to read objects in tenancy usage-report
endorse dynamic-group focus-reports-ADW-DG to read objects in tenancy usage-report

Allow dynamic-group focus-reports-ADW-DG to inspect compartments in tenancy
Allow dynamic-group focus-reports-ADW-DG to inspect tenancies in tenancy

Allow dynamic-group focus-reports-ADW-DG to read autonomous-databases in compartment id ocid1.compartment.oc1....
Allow dynamic-group focus-reports-ADW-DG to read secret-bundles in compartment id ocid1.compartment.oc1....

Allow dynamic-group focus-reports-ADW-DG to read all-resources in tenancy
Allow dynamic-group focus-reports-ADW-DG to manage object-family in compartment id ocid1.compartment.oc1....
```

Replace ocid1.compartment.oc1.... with the deployment compartment OCID.

Reference (Usage Reports Tenancy Definition):
https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/costusagereportsoverview.htm

---

## OCI IAM – Compartment-Level Policy

Create an IAM policy at the deployment compartment level.

Name:
```
focus-reports-compartment-policy
```

Policy Rules:

```
Allow dynamic-group focus-reports-ADW-DG to manage generative-ai-family in compartment id ocid1.compartment.oc1....
Allow dynamic-group focus-reports-ADW-DG to manage genai-agent-family in compartment id ocid1.compartment.oc1....

Allow dynamic-group focus-reports-ADW-DG to use autonomous-databases in compartment id ocid1.compartment.oc1....
Allow dynamic-group focus-reports-ADW-DG to manage object-family in compartment id ocid1.compartment.oc1....
```

Replace ocid1.compartment.oc1.... with the deployment compartment OCID.

---

## OCI GenAI Requirements (Chatbot)

For the AI chatbot functionality to work:

- The OCI tenancy must be subscribed to a region where OCI Generative AI is available
- The Autonomous Database must be able to access GenAI services via Resource Principal

---

### Tested Models

The following GenAI models have been tested:
- Cohere Command-A
- Grok-4

If GenAI is not available:
- chatbot functionality will not operate
- all other application features remain functional

---

## Explicit Non-Requirements

The application does not require:
- OCI API keys
- OCI Vault secrets
- passwords or shared credentials
- external secret stores
- cross-tenancy access
- cross-environment access

---

## Environment Model

Each installation is a standalone environment:
- one OCI tenancy context
- one Autonomous Database
- one APEX application
- no shared state with other environments

Isolation is enforced by OCI tenancy boundaries and IAM policies.

---

## Summary

All security, access, and scope control are enforced by:
- OCI IAM
- Dynamic Groups
- OCI policies
- Resource Principal identity

The application itself does not bypass or weaken OCI security controls.


