# Data Model

## Overview
The application is built around a **cost-centric analytical data model**, enriched with OCI resource metadata, tagging, relationships, configuration, and logging.

The model is optimized for:
- time-series analytics
- drill-down reporting
- NL2SQL query generation
- traceability and auditability

This document focuses on **logical domains**, not every physical column.

---

## Core Data Domains

### 1. Cost Usage Time Series

These tables store normalized OCI cost and usage data.

**Purpose**
- Daily and monthly cost analysis
- Trend comparison (MoM, QoQ, YoY)
- Normalization for unequal month lengths

**Typical Attributes**
- date / month
- service category
- service name
- charge description
- resource identifier
- cost amounts
- currency

These tables are the **primary fact tables** consumed by dashboards and the chatbot.

---

### 2. OCI Resources

These tables represent OCI resources independently of cost.

**Purpose**
- Display resource inventory
- Correlate cost to logical resources
- Enable resource-centric analytics

**Typical Attributes**
- resource identifier (OCID)
- display name
- resource type
- region
- compartment id
- creation timestamp
- defined tags
- freeform tags

Resources may exist **without cost** for a given period.

---

### 3. Resource Relationships

This domain models **parent–child relationships** between OCI resources.

**Purpose**
- Represent hierarchical services (e.g. clusters → nodes)
- Enable roll-up analytics
- Support chatbot reasoning across resource hierarchies

**Typical Attributes**
- parent identifier
- child identifier
- relationship type

This allows dashboards and NL queries such as:
> “Show cost per cluster including all child resources”

---

### 4. Tag Normalization & Attribution

OCI tagging is **not uniform across environments**.  
This application normalizes tags via configuration.

**Purpose**
- Extract standardized values (e.g. cost center, environment)
- Support consistent filtering and grouping
- Avoid hardcoded tag names

**Typical Flow**
1. Raw tags stored as JSON
2. Tag keys resolved from configuration
3. Values extracted dynamically at query time

This avoids breaking analytics when tag conventions change.

---

### 5. Configuration (APP_CONFIG)

Configuration is entirely **data-driven**.

**Purpose**
- Control application behavior
- Store environment-specific values
- Decouple logic from deployment

**Examples**
- OCI compartment roots
- Tag keys for cost attribution
- Region settings
- Feature toggles
- Chatbot model and routing parameters

No secrets should be committed to GitHub.

Details: [configuration.md](configuration.md)

---

### 6. Chatbot Metadata (NL2SQL)

These tables support the NL2SQL chatbot.

**Purpose**
- Map business language to data model
- Control SQL generation without code changes
- Enable explainability and traceability

**Logical Concepts**
- Glossary rules
- Keywords and synonyms
- Metric definitions
- Filter dimensions
- Grouping dimensions

The chatbot operates on **metadata, not heuristics**.

Details: [chatbot.md](chatbot.md)

---

### 7. Logging & Execution Tracing

All major operations are logged.

**Purpose**
- Debug failures
- Audit chatbot behavior
- Trace background jobs

**Typical Logged Data**
- run / request id
- execution timestamp
- status
- generated SQL
- error messages
- partial outputs

This is critical for operating the system in production.

---

## Data Model Characteristics

- Star-like analytics model (facts + dimensions)
- JSON used for flexible metadata (tags, chatbot rules)
- No hardcoded environment assumptions
- Designed for extensibility

---

## How Dashboards Use the Model

- Dashboards read from:
  - views
  - packaged functions
- No direct writes from APEX pages
- All transformations occur in PL/SQL

---

## How the Chatbot Uses the Model

- Discovers available metrics and dimensions dynamically
- Generates SQL against known fact tables
- Applies filters based on glossary rules
- Logs every step

