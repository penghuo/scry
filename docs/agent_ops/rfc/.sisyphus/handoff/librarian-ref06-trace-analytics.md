# Data Prepper Trace Analytics — Reference Summary

**Source:** https://docs.opensearch.org/latest/data-prepper/common-use-cases/trace-analytics/

## Overview

Data Prepper is a server-side ingestion component that receives OpenTelemetry trace data,
transforms it, and writes derived analytics data into OpenSearch. The transformed data powers
the Observability plugin in OpenSearch Dashboards for distributed trace visualization.

## End-to-End Flow

1. **Application instrumentation** generates telemetry (OpenTelemetry SDK)
2. **OpenTelemetry Collector** (sidecar/daemonset/agent) exports trace data to Data Prepper
3. **Data Prepper** ingests, enriches, and writes to OpenSearch
4. **OpenSearch Dashboards** (Observability plugin) visualizes traces and service maps

## Pipeline Architecture (3-Pipeline Design)

### entry-pipeline
- **Source:** `otel_trace_source` — accepts OTLP/gRPC from OpenTelemetry Collector
- **Role:** Fan-out entry point; receives raw span data
- **Sinks:** Forwards to both `raw-trace-pipeline` and `service-map-pipeline`

### raw-trace-pipeline
- **Source:** `pipeline` (from entry-pipeline)
- **Processor:** `otel_traces` — stateful processing of span records; extracts and completes
  trace-group-related fields (traceGroup name, endTime, durationInNanos, statusCode)
- **Optional processor:** `otel_traces_group` — backfills missing trace-group fields by
  querying the OpenSearch backend
- **Sink:** OpenSearch with `index_type: trace-analytics-raw`
- **Target index:** `otel-v1-apm-span` (alias → `otel-v1-apm-span-000001`)

### service-map-pipeline
- **Source:** `pipeline` (from entry-pipeline)
- **Processor:** `service_map` — aggregates span relationships over a configurable
  `window_duration` (default 180s) to build service-to-service dependency metadata
- **Sink:** OpenSearch with `index_type: trace-analytics-service-map`
- **Target index:** `otel-v1-apm-service-map`

## Derived Data Produced

### Span Documents (`otel-v1-apm-span`)
Each span document contains:
- `traceId`, `spanId`, `parentSpanId`, `traceState`
- `name`, `kind` (CLIENT/SERVER/INTERNAL/etc.)
- `serviceName`, `traceGroup` (root span operation name)
- `startTime`, `endTime`, `durationInNanos`
- `status.code`, `traceGroupFields` (endTime, durationInNanos, statusCode of root span)
- `span.attributes.*` (e.g., `peer@service`, `network@peer@address`)
- `resource.attributes.service@name`
- `events`, `links`, dropped counts

### Service Map Documents (`otel-v1-apm-service-map`)
- Service-to-service relationship edges derived from span parent/child and `peer@service` attributes
- Built from a sliding time window of recent trace data

## Key Architectural Details

- **Fan-out pattern:** Single entry pipeline splits into two independent processing paths,
  enabling different processing cadences (raw trace can use longer delay for bulk writes;
  service-map uses shorter delay for near-real-time topology)
- **Stateful processing:** `otel_traces` processor maintains state to correlate root spans
  with child spans for trace-group enrichment
- **Horizontal scaling:** Peer forwarder enables multi-instance clusters; traces with the
  same traceId are routed to the same instance for correct stateful aggregation
- **Buffering:** `bounded_blocking` buffers decouple ingestion rate from processing rate;
  `buffer_size >= workers * batch_size` is the sizing rule

## Relevance to Investigation Summaries

- The `traceGroup` field identifies the root operation — useful for categorizing investigation traces
- `durationInNanos` and `traceGroupFields` provide latency context for anomaly detection
- `serviceName` + service-map edges reveal blast radius and dependency chains
- Span attributes carry request-level context (peer services, network addresses)
- The two-index design separates per-span detail from aggregated topology, enabling
  both deep-dive and high-level investigation views
