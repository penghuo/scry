# OpenSearch Observability — Reference Summary

> Source: https://docs.opensearch.org/latest/observing-your-data/
> Fetched: 2025 (latest docs)

## Overview

OpenSearch Observability is a collection of plugins and Dashboards applications that let you
visualize data-driven events using **Piped Processing Language (PPL)** to explore, discover,
and query logs, traces, and metrics stored in OpenSearch.

## Data Organization: Three Pillars + Event Analytics

### 1. Logs
- **Log ingestion** via Data Prepper, Logstash, or direct indexing.
- **Event analytics**: PPL-based exploration in Dashboards → Observability → Logs.
- PPL queries generate visualizations (bar, pie, line, etc.) that can be saved and added to dashboards.
- **Live Tail**: real-time log streaming at configurable intervals (similar to `tail -f`).
- **Surrounding events**: expand context around a log event for investigation.
- Log-trace correlation via `TraceId` field (OpenTelemetry standard).
- **Limitation**: Event analytics visualizations only support PPL — no DQL or DSL filters.

### 2. Traces
- **Trace analytics** ingests and visualizes OpenTelemetry span data.
- Visualizes distributed request flows across services (service maps, span detail views).
- Supports **Jaeger** trace data natively when OpenSearch is the Jaeger backend.
- Dashboards plugin shows: service map, trace list, span detail, latency histograms.
- Requires Data Prepper `otel-trace-source` pipeline or Jaeger-compatible ingestion.

### 3. Metrics
- **Metric analytics** (introduced 2.4) ingests and visualizes metric data directly in OpenSearch.
- Two data source types:
  - **OpenTelemetry metrics index** (OTel-compatible, via Data Prepper `otel-metrics-source`).
  - **Prometheus data source** (federated via SQL plugin `_datasources` API).
- Supports remote cluster metric visualization (introduced 2.14).
- Custom metric visualizations via PPL queries with time-series + stats/span.

## Simple Schema for Observability (SS4O)

- Standardized schema convention (`ss4o`) introduced in 2.6.
- Inspired by OpenTelemetry and Elastic Common Schema (ECS).
- Defines index structure (mapping), naming conventions, JSON schema for validation.
- Enables automatic extraction, aggregation, and preconfigured dashboards via integrations.
- Data Prepper conforms for metrics; traces and logs integration is progressive.

## Exploring Observability Data (Unified Discover)

- **Datasets**: browse available observability data sources.
- **Discover Logs / Traces / Metrics**: dedicated exploration views per signal type.
- **Correlations**: cross-signal correlation (e.g., log ↔ trace via TraceId).

## Additional Capabilities

| Feature | Description |
|---|---|
| **Application analytics** | Group logs, traces, and metrics by application for unified view |
| **Operational panels** | Custom dashboards combining multiple PPL visualizations |
| **Notebooks** | Combine visualizations + code blocks, shareable with team |
| **Alerting** | Monitors (per-query, per-bucket, per-document, composite), triggers, actions |
| **Anomaly detection** | ML-based anomaly detection on time-series data with alerting integration |
| **Forecasting** | Time-series forecasting (introduced later releases) |
| **Query insights** | Top N queries, live queries, query metrics for self-observability |
| **Notifications** | Configurable notification channels (Slack, email, webhook, etc.) |

## Key Features for Investigation Workflows

- **PPL as primary query language**: pipe-based, supports stats, dedup, eval, patterns, rare, timechart, trendline, join, subsearch, kmeans, anomaly detection (`ad` command).
- **OpenSearch Assistant / Query Assistant**: natural language → PPL conversion (LLM-powered).
- **Log-trace correlation**: automatic linking when TraceId is present in logs.
- **Cross-cluster search**: query observability data across federated OpenSearch clusters.
- **Saved searches & visualizations**: persist and reuse investigation queries.

## Limitations & Gaps (RFC-relevant)

1. **No unified investigation workflow**: logs, traces, metrics are separate views — correlation requires manual TraceId linking.
2. **PPL-only for event analytics**: no DQL/DSL support in observability visualizations; dashboard filters don't apply to PPL visualizations.
3. **No investigation state management**: no concept of an "investigation" that tracks hypotheses, evidence, or findings across signals.
4. **Schema adoption is progressive**: SS4O covers metrics well, but traces/logs integration with Data Prepper is still evolving.
5. **Alerting is reactive, not investigative**: monitors detect conditions but don't guide root-cause analysis.
6. **No built-in runbooks or automated remediation**: alerting triggers actions (notifications) but lacks structured investigation playbooks.
7. **Anomaly detection is standalone**: results don't automatically feed into a unified investigation context.
8. **Metric federation is read-only**: Prometheus metrics are queried via PPL but not natively indexed (unless using OTel pipeline).

## Source URLs

- Main: https://docs.opensearch.org/latest/observing-your-data/
- SS4O: https://docs.opensearch.org/latest/observing-your-data/ss4o/
- Event analytics: https://docs.opensearch.org/latest/observing-your-data/event-analytics/
- Trace analytics: https://docs.opensearch.org/latest/observing-your-data/trace/index/
- Metric analytics: https://docs.opensearch.org/latest/observing-your-data/prometheusmetrics/
- Exploring data: https://docs.opensearch.org/latest/observing-your-data/exploring-observability-data/index/
- Alerting: https://docs.opensearch.org/latest/observing-your-data/alerting/index/
- Anomaly detection: https://docs.opensearch.org/latest/observing-your-data/ad/index/
