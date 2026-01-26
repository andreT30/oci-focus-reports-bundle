# OCI Cost Analytics & NL2SQL Chatbot
**Oracle APEX • Oracle Autonomous Database • OCI FinOps**

A production-grade Oracle APEX application for OCI cost analytics, reporting, and governance.  
Includes an explainable NL2SQL chatbot that lets users ask cost/usage questions in natural language.

---

## What you get

### Cost & usage analytics
- Daily and monthly cost/usage analysis with drill-downs
- Trend views (MoM / QoQ) and simple projections
- Credit tracking (PAYG and non-PAYG)

### Dashboards & reports
- Executive overview dashboards
- Flexible reports with saved views
- Drill-down: overview → workload → resource

### OCI resource visibility
- Resource inventory across compartments/regions
- Parent–child relationships (where available)
- Tag-based attribution and filtering

### NL2SQL AI chatbot
- Natural-language questions (example: “cost last month by service”)
- Metadata-driven SQL generation (no “free-form guessing”)
- Fully logged: prompt inputs, reasoning, SQL, results, errors
- Guardrails (row limits, allowlists, safe execution patterns)

### Enterprise-ready foundations
- Database-first logic in PL/SQL
- Configuration over hardcoding
- Auditable operations and traceable changes
- Designed to run without secrets in source control

---

## Who this is for
- **FinOps / Finance**: spend visibility, trends, credits, chargeback/showback
- **Engineering / Operations**: workload and service analytics
- **Platform owners / Architects**: governance, tagging, accountability
- **Executives / Stakeholders**: high-level insights without needing SQL

End users do not need Oracle or SQL knowledge.

---

## Alignment with the FOCUS FinOps standard
This project is designed to support the **FOCUS (FinOps Open Cost and Usage Specification)** use cases maintained by the FinOps Foundation.  
In practice, the app helps teams **find**, **organize**, **compute**, and **optimize** cloud spend using curated analytics plus natural-language exploration.

<p align="center">
  <img
    src="https://focus.finops.org/wp-content/uploads/2025/12/BG-Image-v3.png"
    alt="FOCUS FinOps Framework"
    width="600"
  />
</p>

*Source: https://focus.finops.org/*

---

## Documentation
- [Infrastructure Requirements](docs/infra-requirements.md)
- [Deployment](docs/deployment.md)
- [Configuration](docs/configuration.md)
- [Administration & Operations](docs/admin-guide.md)
- [User Guide](docs/usage-guide.md)
- [NL2SQL Chatbot](docs/chatbot.md)
- [Security & Trust Model](docs/security.md)
- [Data Model](docs/data-model.md)
- [Architecture](docs/architecture.md)
- [APEX Pages Map](docs/apex-pages.md)
- [Troubleshooting](docs/troubleshooting.md)

---

## Quick start path
1. Read **Infrastructure Requirements** and confirm prerequisites.
2. Deploy the app bundle using the **Deployment Manager**.
3. Configure `APP_CONFIG` and enable scheduled refresh jobs.
4. Validate dashboards and run a few chatbot questions.

See [Deployment](docs/deployment.md) for the full procedure.

---

## Repository layout (high level)
- `docs/` – documentation
- `screenshots/` – documentation screenshots
- (bundles, SQL, and app export are managed by the in-app deployment tooling)

---

## Support and contribution
This repository focuses on clarity and portability:
- no environment-specific values in code
- configuration stored in tables
- export/import via the built-in Deployment Manager

If you find gaps in documentation or want additional examples, open an issue or submit a PR.
