# OpenSearch Trace Analytics — Getting Started Summary

> Source: https://docs.opensearch.org/latest/observing-your-data/trace/getting-started/
> Supplementary: https://docs.opensearch.org/latest/observing-your-data/trace/ta-dashboards/

## Architecture & Setup Flow

Trace Analytics has two components: **Data Prepper** (backend processor) and the **Trace Analytics Dashboards plugin** (UI).

**Data pipeline:**
1. Application instrumented with OpenTelemetry SDK generates trace data
2. OpenTelemetry Collector receives and formats data into OTel protocol
3. Data Prepper processes OTel data, transforms it, and indexes into OpenSearch
4. Dashboards plugin renders near-real-time visualizations

**Required infrastructure:** OTel-instrumented app → OTel Collector → Data Prepper → OpenSearch + Dashboards

**Schema requirements:**
- Data must follow OTel schema conventions (Simple Schema for Observability / SS4O)
- Unique, consistent `serviceName` across components
- Consistent trace/span IDs across distributed systems
- RED metrics (Rate, Error, Duration) either preaggregated by Data Prepper or calculated from spans
- Correlation fields (`serviceName`, `spanId`, `traceId`) must be present for cross-signal navigation

## Visualizations & Features

### Services View
- **Services table**: RED metrics per service, connected upstream/downstream services, 24h throughput tooltip
- **Service map**: Node graph where color indicates RED severity; click nodes for detail dialogs
- **Service correlation dialog**: At-a-glance service details with links to correlated logs/traces
- **Focus on**: Isolate a service and its dependencies in the map

### Traces View
- **Trace Groups**: Groups traces by HTTP method + path; shows avg latency, error rate, trends
- **Trace detail**: Waterfall/Gantt chart of spans with timing, hierarchical tree view (3.1+), pie chart summary
- **Span detail flyout**: Individual span attributes, associated logs link

### Correlation Analysis (key for investigation)
- **Trace-to-log**: From trace details → "View associated logs"
- **Span-to-log**: From span detail flyout → "View associated logs"
- **Service-to-log**: From services page → Discover icon
- **Service-to-service**: Service map "Focus on" for dependency view

### Recent Enhancements (3.1+)
- Custom index names for span/service/log indexes (non-OTel log field mapping supported)
- Associated logs panel on trace detail page
- Dropdown to filter: all spans, root spans, service entry spans, or traces
- Gantt chart mini-map for timeline navigation
- Redesigned service map for large topologies
- Configurable service map limits (max nodes: 500 default, max edges: 1000 default) — tunable in Advanced Settings (3.2+)

## Gaps & Limitations Relevant to Investigation Workflows

1. **Data Prepper dependency**: No alternative ingestion path — must use Data Prepper pipelines (trace analytics + service map pipelines) for proper indexing and preaggregation
2. **No built-in anomaly detection on traces**: RED metrics are displayed but no automated alerting or anomaly detection is natively integrated into the trace view
3. **Correlation requires schema compliance**: Log correlation only works if logs follow SS4O naming conventions or custom field mappings are configured (3.1+)
4. **No programmatic/API-driven investigation**: The trace analytics features are UI-only in Dashboards; no dedicated REST API for trace-level queries beyond raw OpenSearch index queries
5. **Service map scalability**: Default limits (500 nodes, 1000 edges) may truncate large topologies; higher values increase browser resource usage
6. **No root cause analysis automation**: The tool shows topology and metrics but doesn't suggest root causes — investigation is manual
7. **Jaeger support is separate**: Jaeger trace data requires a different setup path (separate doc page)
8. **No built-in comparison**: Cannot compare traces across time windows or A/B deployments natively
