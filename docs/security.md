# Security & Trust Model

This document describes how the application enforces security, privacy, and trust.
It is written for:
- security reviewers
- architects
- auditors
- administrators

The security model is **cloud-native, policy-driven, and auditable**.

---

## Security Principles

The application is built on the following principles:

- **No secrets**
- **Least privilege**
- **Policy-driven access**
- **No PII exposure to AI services**
- **Database-enforced controls**
- **Full auditability**

Security is enforced primarily by **OCI IAM policies**, not application logic.

---

## Authentication

Authentication is handled by **Oracle APEX** and supports:

- **Oracle APEX Accounts**
- **OCI Single Sign-On (SSO)**, including:
  - OCI IAM
  - Federated identity providers
  - Enterprise SSO integrations

The application does **not** implement custom authentication mechanisms.

---

## Authorization Model

### Roles

The application currently defines **two roles only**:

- **End Users**
  - dashboards
  - reports
  - chatbot usage

- **Administrators**
  - configuration
  - job control
  - chatbot metadata
  - update workflows

Authorization is enforced via:
- APEX authorization schemes
- role-based access at page and component level

---

## OCI Resource Principal (No Credentials)

### Identity Model

The database uses **OCI Resource Principal** (`OCI$RESOURCE_PRINCIPAL`) exclusively.

- No API keys
- No passwords
- No stored credentials
- No secrets in code or configuration

All OCI access originates from the database **as an OCI resource**.

---

### Dynamic Groups & Policies

Access to OCI services and resources is controlled by:

- **OCI Dynamic Groups**
- **OCI IAM Policies**

This ensures:
- central enforcement
- full auditability in OCI
- zero credential leakage risk

The application itself cannot bypass these policies.

---

## Compartment & Scope Control

OCI data visibility is constrained by:

- Dynamic Group membership
- OCI IAM policies
- configured root compartments

The application can only access:
- compartments
- regions
- services
explicitly allowed by OCI policy.

There is **no application-level override** of OCI scope.

---

## PII Protection and LLM Safety

The application enforces a strict **no-PII-to-LLM** policy.

### Tokenization model

- All PII handling occurs **inside the database**
- Sensitive values are **tokenized before any LLM interaction**
- Tokenization is irreversible outside the database context

### LLM interaction

- LLMs receive **tokenized placeholders only**
- No raw PII, secrets, or personal data are transmitted
- External AI services never see real identifiers or values

### Response rendering

- LLM responses return tokenized placeholders
- De-tokenization occurs **inside the database**
- Only the final UI output contains resolved values

### Security guarantee

- **PII is never sent to any LLM**
- Tokenization is deterministic and auditable
- Privacy policies are enforced by design, not convention

---

## Chatbot Security (NL2SQL)

The chatbot is **deterministic and constrained**:

- SQL is generated only from predefined metadata
- Allowed tables, columns, and filters are whitelisted
- Free-form SQL execution is not possible

Additional safeguards:
- execution limits
- time-range constraints
- full SQL logging

Every chatbot request is traceable end-to-end.

---

## Secrets Management

There are **no secrets** in this system.

Specifically:
- no OCI API keys
- no OAuth secrets
- no passwords
- no tokens stored in tables or config
- no secrets in GitHub

Identity and access are fully delegated to OCI IAM.

---

## Logging & Auditability

The system logs:
- authentication events (via APEX / OCI)
- deployment and update runs
- scheduler job executions
- chatbot requests and generated SQL
- errors and warnings

Logs are:
- queryable
- correlated by run/request IDs
- suitable for audits and incident analysis

---

## Environment Model

Each installation is a **standalone environment**:

- one database
- one APEX application
- one OCI tenancy context

There is:
- no shared state
- no cross-environment access
- no implicit trust between environments

Isolation is inherent by deployment model.

---

## Common Security Questions

### “Does the app store or transmit OCI credentials?”
No. It uses OCI Resource Principal exclusively.

---

### “Can the LLM see personal data?”
No. All PII is tokenized before any LLM call.

---

### “Can admins bypass OCI policies?”
No. OCI IAM policies are authoritative.

---

### “Is this auditable?”
Yes. All actions and data paths are logged and explainable.

---

## Final Statement

This application uses **OCI-native security controls**, avoids secret-based access,
and enforces privacy by design.

Trust is not assumed — it is **provable**.

**See also**
- [Admin Guide](admin-guide.md)
- [Deployment Guide](deployment.md)
