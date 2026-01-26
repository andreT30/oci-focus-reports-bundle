# Data Model

Home: [README](../README.md) · **Docs** · **Data Model**

The application uses a cost-centric analytical model enriched with OCI resource metadata, tags, relationships, configuration, and logs.
This document describes the **logical domains** (not every physical column).

---

## Core domains

### 1) Cost & usage time series (facts)
Purpose:
- daily/monthly cost and usage analysis
- trending and period comparisons (MoM/QoQ/YoY)
- consistent time buckets for reporting and chatbot queries

Typical attributes:
- `DATE_BUCKET` (day/month)
- service and SKU descriptors
- resource identifiers (OCIDs when available)
- cost and usage measures (currency, unit)

These are the primary datasets used by dashboards and the chatbot.

### 2) OCI resources (inventory)
Purpose:
- present resource inventory independent of cost
- enrich cost data with names, types, regions, compartments, and tags
- enable resource-centric exploration and drill-down

Typical attributes:
- OCID, display name, resource type
- region and compartment
- creation timestamp
- defined/freeform tags

Resources may exist without cost in a given period (and vice versa).

### 3) Resource relationships (hierarchies)
Purpose:
- model parent/child relationships (where the OCI API provides them)
- support rollups (example: cluster cost including child resources)
- enable “show me what is under this resource” exploration

### 4) Workloads and tagging (attribution)
Purpose:
- map resources and/or cost lines into business entities (teams, products, workloads)
- power chargeback/showback style reporting and filtering

Implementation is typically driven by:
- compartment structure
- defined/freeform tags
- configurable mapping rules

### 5) Configuration (control plane)
Purpose:
- store environment configuration and feature flags (`APP_CONFIG`)
- store chatbot metadata (glossary rules, parameters)
- keep runtime behavior consistent across environments

### 6) Logging (audit and supportability)
Purpose:
- record deployment and update runs
- record scheduler job runs
- capture chatbot request traces (inputs, reasoning artifacts, SQL, execution metadata, errors)

---

## Practical navigation
- For configuration tables: [Application Configuration (APP_CONFIG)](app-config.md)
- For chatbot metadata and logs: [NL2SQL Chatbot](chatbot.md)
- For operational logs: [Administration & Operations](admin-guide.md)
