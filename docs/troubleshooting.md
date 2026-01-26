# Troubleshooting

Home: [README](../README.md) · **Docs** · **Troubleshooting**

This page covers the most common operational issues and how to narrow them down quickly.

---

## Start here (always)
Most components log their behavior. When raising an issue, capture:
- timestamp (and timezone)
- page/job name
- run id / request id (if available)
- exact error text
- what changed recently (update, config change, new data source)

---

## Common issues

### Dashboards are empty
Likely causes:
- refresh jobs have not run
- `APP_CONFIG` scope excludes the compartments you expect
- cost/usage source objects are not reachable (IAM/policy)
- date defaults point to an unexpected window

What to check:
- most recent job runs (success/failure)
- key `APP_CONFIG` values
- whether base staging tables contain any recent rows

### Data looks stale
Likely causes:
- scheduler jobs disabled
- a job is failing silently (retry loop) or running too long
- source report delivery is delayed

What to check:
- job last-run timestamp and runtime trend
- ingestion logs for the last successful load
- upstream report generation schedule (outside the app)

### Chatbot errors / unexpected SQL
Likely causes:
- GenAI permissions/service availability
- overly broad question causing routing ambiguity
- glossary rules missing for a business term (workload/service synonym)
- guardrails blocking execution (by design)

What to check:
- chatbot log table entry for the request (prompt JSON, generated plan, SQL, error)
- glossary rule coverage for the keywords in the question
- configured limits (row cap, allowed tables, time window defaults)

See: [NL2SQL Chatbot](chatbot.md)

---

## When you need deeper detail
- [Administration & Operations](admin-guide.md)
- [Security & Trust Model](security.md)
- Deployment run history (if the issue followed an update): [Update](update.md)
