# User Guide

This guide explains how to use the application as an **end user** to analyze OCI cost, usage, resources, and trends, and how to ask questions using the built-in AI chatbot.

No Oracle or SQL knowledge is required.

---

## Getting Started

### What this application does
The application provides:
- clear visibility into OCI cost and usage
- resource-level and workload-level cost attribution
- historical trends and comparisons
- natural-language querying via an AI chatbot

All data is refreshed automatically via background jobs.

---

## Page 1 — Home Dashboard

### Purpose
The Home page is the **executive overview** of OCI spend and consumption.

Use this page to:
- understand current and projected costs
- identify top workloads and cost drivers
- spot trends and anomalies quickly

---

### What you see

#### Subscription & Credit Overview
- active subscriptions
- available credits
- consumed credits
- projected depletion timelines

This helps answer:
> “Are we on track with our OCI credits?”

---

#### Cost & Usage Trends
- monthly cost evolution
- weekly usage patterns
- consolidated workload trends

You can visually identify:
- cost increases or drops
- seasonality
- abnormal spikes

---

#### Workload Cost Breakdown
- cost per workload
- top contributors
- consolidated vs individual views

This answers:
> “Which workloads cost the most right now?”

---

### How to use it effectively
1. Start here daily or weekly
2. Identify anomalies or spikes
3. Drill down using **Workloads**, **Cost Report**, or **Usage Report**

---

## Page 2 — OVBot (AI Chatbot)

### Purpose
The chatbot allows you to **ask questions in natural language** instead of building reports.

You can ask:
- “Total cost last month by service”
- “Top workloads this quarter”
- “Cost per cluster including child resources”
- “Which services increased cost month over month?”

---

### How it works (from the user’s perspective)
1. Type a question
2. Click send
3. Review:
   - the answer
   - the data table
   - optional charts
   - explanation of what was queried

The system translates your question into SQL automatically.

---

### Best practices for good answers
- Use clear time references (“last month”, “this quarter”)
- Mention what you want grouped by (“by service”, “per workload”)
- Avoid overly long sentences

The chatbot is **deterministic and explainable**, not a black box.

---

## Page 3 — Workloads

### Purpose
Analyze cost and trends **by workload**, not just by service.

Workloads represent logical groupings of resources.

---

### What you can do
- see cost trends per workload
- compare workloads over time
- drill down into workload components
- identify high-cost or growing workloads

---

### Typical questions answered
- “Which workload increased cost the most?”
- “How does workload A compare to workload B?”
- “Which workloads drive monthly spend?”

---

### How to use it
1. Select one or more workloads
2. Adjust the time range
3. Use charts to spot trends
4. Drill down when needed

---

## Page 4 — Usage Report

### Purpose
Analyze **usage metrics**, not just cost.

This page focuses on:
- quantities
- consumption patterns
- service usage behavior

---

### Use cases
- validate expected usage
- correlate usage to cost
- identify inefficient consumption

---

### How to use it
1. Select filters (service, resource, date)
2. Review tabular and chart outputs
3. Adjust grouping to explore patterns

---

## Page 5 — Cost Report

### Purpose
Deep-dive into **cost dimensions** with full flexibility.

---

### What makes this page powerful
- multiple filters (service, resource, compartment, tag)
- grouping by different dimensions
- flexible time selection

---

### Typical use cases
- chargeback / showback
- service-level cost analysis
- monthly or quarterly reporting

---

### How to use it
1. Start with a broad filter
2. Narrow down dimensions
3. Group by what matters (service, workload, resource)
4. Export results if needed

---

## Page 6 — Resource Explorer

### Purpose
Explore OCI resources and understand **what exists**, regardless of cost.

---

### What you can see
- resource inventory
- resource attributes
- regions and compartments
- tags (defined and freeform)

---

### Why this matters
- some resources may not generate cost
- helps explain cost allocation
- supports discovery and governance

---

## Page 7 — My Reports

### Purpose
Access **saved and predefined reports**.

---

### Use cases
- reuse common analyses
- standardize reporting
- share insights internally

---

## Page 8 — OCI Calculator

### Purpose
Utility calculators that support cost analysis workflows.

---

### Typical usage
- what-if scenarios
- sanity checks
- estimation support

---

## Page 300 — Availability Metrics

### Purpose
View availability-related KPIs and metrics.

This is typically used by:
- operations teams
- reliability analysis
- service health reviews

---

## Navigation Tips

- Start at **Home**
- Use **Workloads** for accountability
- Use **Cost Report** for finance
- Use **Usage Report** for engineering
- Use **Resource Explorer** for discovery
- Use **OVBot** when you don’t know where to start

---

## Common User Journeys

### “Why did cost increase?”
1. Home → identify spike
2. Workloads → isolate workload
3. Cost Report → break down by service
4. Resource Explorer → identify culprit resource

---

### “What will this cost us?”
1. Home → projections
2. Cost Report → historical trends
3. Chatbot → natural language summary

---

## Final Notes
- The system is fully auditable
- All results are derived from OCI source data
- Configuration and tagging strongly affect attribution quality

If something looks wrong, it is almost always:
- missing tags
- misconfigured workload
- incomplete data for the selected period
