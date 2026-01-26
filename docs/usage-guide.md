# User Guide

Home: [README](../README.md) · **Docs** · **User Guide**

This guide is for end users who want to explore OCI cost and usage data, resource metadata, and trends.
No SQL knowledge is required.

---

## Getting started
A typical workflow:
1. Open the **Home dashboard** to understand current spend and key drivers.
2. Use filters (date range, compartment, workload, tags) to focus your view.
3. Drill down from summary views to workload/resource details.
4. Use the **chatbot** for ad-hoc questions or “why did this change?” exploration.

---

## Dashboards and reports
General tips:
- Start broad, then drill down (service → workload → resource).
- Use consistent time ranges when comparing charts/tables.
- Save commonly used report configurations if your deployment enables saved views.

Common outcomes:
- identify top spend areas
- spot trend changes early (MoM/QoQ)
- attribute cost by workload/team via tags
- validate commitment/credit consumption patterns

---

## Filters and attribution
Depending on your configuration and available data, you can filter by:
- compartment hierarchy
- workload mapping (usually driven by tags or naming rules)
- service category / SKU attributes
- resource identifiers and relationships

If a filter looks empty, it usually indicates missing metadata or a configuration scope issue (see Troubleshooting).

---

## Using the chatbot
Use the chatbot when you want fast answers without building a report.

Good question patterns:
- “total cost last month by service”
- “top 10 workloads by cost this quarter”
- “which services increased MoM”
- “cost trend for <workload> over the last 6 months”

If results look surprising:
- check the time range assumption (some views use a “snapshot day” default)
- ask a follow-up question (“show me the SQL” / “what filters were applied”)
- confirm workload/tag mappings

See: [NL2SQL Chatbot](chatbot.md)

---

## Exporting and sharing
If enabled, reports and charts can be exported to common formats (CSV/PNG/PDF).
For regulated environments, follow your organization’s rules for handling cost and resource data.

---

## Where to go next
- [APEX Pages Map](apex-pages.md)
- [Troubleshooting](troubleshooting.md)
