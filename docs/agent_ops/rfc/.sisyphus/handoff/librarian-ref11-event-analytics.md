# OpenSearch Event Analytics — Reference Summary

**Source:** https://docs.opensearch.org/latest/observing-your-data/event-analytics/
**Context:** OpenSearch Observability > Event Analytics

## Overview

Event Analytics is a feature within OpenSearch Observability that enables interactive
log exploration and data visualization using **Piped Processing Language (PPL)** queries.
It is accessed via **Observability > Logs** in OpenSearch Dashboards.

## PPL as the Query Engine

- PPL is the **sole query language** for Event Analytics — not DQL or Query DSL.
- Users write PPL queries that OpenSearch Dashboards automatically renders into visualizations.
- Example query: `source = opensearch_dashboards_sample_data_logs | fields host | stats count()`
- PPL supports a rich command set relevant to investigation workflows:
  - `source` — select index/data source
  - `fields` — project specific fields
  - `stats` — aggregate (count, avg, sum, etc.)
  - `where` — filter conditions
  - `dedup` — deduplicate events
  - `sort`, `head`, `rare`, `top` — ordering and frequency analysis
  - `eval` — computed fields
  - `parse`, `grok`, `rex` — extract fields from unstructured log text
  - `patterns` — discover log patterns
  - `timechart` — time-series aggregation
- PPL also supports federated data sources (e.g., Prometheus, Amazon S3).

## Query Assistant (AI-Powered)

- OpenSearch Assistant can convert **natural language → PPL** queries.
- Configurable via `opensearch_dashboards.yml` settings.
- Supports response summarization for query results and errors.

## Saved Queries & Visualizations

- Visualizations generated from PPL queries can be **saved by name** and reopened later.
- Saved visualizations can be added to **Operational Panels** for reusable dashboards.
- Since Dashboards 2.7, PPL visualizations can be embedded into standard **Dashboards**:
  1. Create via **Visualize > PPL** or from the Logs Explorer.
  2. Choose visualization type (Pie, Bar, etc.) from the sidebar.
  3. Save and add to any dashboard via **Add an existing > PPL** type filter.

## Investigation-Relevant Features

### Log-Trace Correlation
- Logs indexed with a `TraceId` field (OpenTelemetry standard) can be correlated
  with distributed traces directly in the event explorer log detail view.
- Enables jumping from a log event to its full trace context.

### Surrounding Events
- "View surrounding events" shows log entries around a selected event's timestamp,
  providing temporal context during incident investigation.

### Live Tail (Real-Time Streaming)
- Streams logs in real-time to the Event Analytics UI using a specified PPL query.
- Configurable refresh intervals; similar to `tail -f`.
- Displays total incoming log count for traffic pattern awareness.
- Supports filters during live streaming.

## Limitations

- Event Analytics visualizations do **not** support DQL or Query DSL filters.
- They do **not** use index patterns — only PPL `source` directives.
- Dashboard-level DQL/DSL filters are ignored by PPL visualizations.
- The filter dropdown only shows fields from default index patterns or patterns
  used by other (non-PPL) visualizations on the same dashboard.

## Relevance to Investigation Workflows

Event Analytics provides the interactive, PPL-driven exploration layer that an
investigation agent would use to:
1. **Query logs** across indices and federated sources using PPL pipes.
2. **Correlate logs with traces** via TraceId for cross-signal investigation.
3. **Save and reuse queries** as named visualizations or operational panel components.
4. **Stream live logs** during active incident response.
5. **Explore surrounding context** around anomalous events.

The PPL tool in OpenSearch's ML agent framework (`PPLTool`) directly leverages
this same PPL execution engine, making Event Analytics the human-facing counterpart
to agent-driven PPL queries.
