# Troubleshooting

## General Approach
All components log their behavior.
Always start by identifying:
- run id
- request id
- timestamp

---

## Common Issues

### 1. Empty Dashboards
Possible causes:
- missing cost data
- incorrect compartment config
- wrong date range defaults

Check:
- APP_CONFIG values
- cost refresh job logs

---

### 2. Job Failures
Possible causes:
- OCI permission changes
- malformed input data
- schema changes

Check:
- job run logs
- error stack in logging tables

---

### 3. Chatbot Returns No Results
Possible causes:
- missing glossary coverage
- ambiguous input
- no data for period

Check:
- chatbot execution logs
- generated SQL
- applied filters

---

### 4. Incorrect Cost Attribution
Possible causes:
- tag key mismatch
- incomplete tagging
- resource relationship gaps

Check:
- tag configuration
- raw tag JSON
- relationship tables

---

## Logging Tables

The system logs:
- job execution
- chatbot requests
- SQL generation
- errors and warnings

Logs are designed to be:
- queryable
- correlated via IDs
- retained for audit

---

## Debug Strategy

1. Reproduce the issue
2. Capture run/request id
3. Inspect generated SQL
4. Validate configuration
5. Adjust glossary or config if needed

---

## Support Checklist

Before raising an issue:
- capture timestamps
- capture request id
- export logs
- note environment

