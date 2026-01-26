# Security & Trust Model

Home: [README](../README.md) · **Docs** · **Security & Trust Model**

This document explains how the application approaches security, privacy, and auditability.
Audience: security reviewers, architects, administrators, and auditors.

---

## Security principles
- **No secrets in source control**: no API keys, passwords, or embedded credentials
- **Least privilege**: IAM policies scoped to the smallest required compartment/tenancy
- **Policy-driven access**: OCI IAM controls data access, not application-side “magic”
- **Auditable by default**: deployments, jobs, and chatbot executions are logged
- **Safe execution boundaries**: row limits, allowlists, and validation steps for query execution

---

## Identity and access
### Resource Principal
When running in Autonomous Database, the application uses **OCI Resource Principal** to access OCI services.
This removes the need for stored secrets and aligns with OCI best practices.

### IAM dynamic groups and policies
Access is granted through:
- a dynamic group matching the Autonomous Database resource
- policies that permit only the required actions (read usage reports, use GenAI, etc.)

See: [Infrastructure Requirements](infra-requirements.md)

---

## Data handling and privacy
- Cost and usage data is treated as sensitive operational data.
- Where the chatbot is enabled, inputs/outputs are logged for traceability.
- If tokenization/redaction is enabled in your deployment, sensitive tokens can be masked before LLM calls and rehydrated after summarization (implementation-dependent).

Recommended operational controls:
- restrict admin pages to a small operator group
- apply APEX authorization schemes consistently
- review log retention policies (align with your compliance requirements)

---

## Chatbot trust boundaries
The chatbot is designed to be **explainable and constrained**:
- the LLM produces structured JSON (not raw SQL)
- final SQL is generated/validated deterministically
- execution is constrained by configured guardrails
- every request is logged (question, derived intent, SQL, result metadata, errors)

See: [NL2SQL Chatbot](chatbot.md)

---

## Auditability
You should be able to answer:
- “what changed?” (deployment runs / applied artifacts)
- “what ran?” (scheduler job runs)
- “who asked what?” (chatbot request logs, APEX session context)

See:
- [Update](update.md)
- [Administration & Operations](admin-guide.md)
