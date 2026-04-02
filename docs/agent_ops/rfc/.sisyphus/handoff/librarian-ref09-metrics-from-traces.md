# Reference: Deriving Metrics from Traces — OpenSearch Data Prepper

**Source:** https://docs.opensearch.org/latest/data-prepper/common-use-cases/metrics-traces/
**Supplementary:** [Trace Analytics](https://docs.opensearch.org/latest/data-prepper/common-use-cases/trace-analytics/), [Aggregate Processor](https://docs.opensearch.org/latest/data-prepper/pipelines/configuration/processors/aggregate/)

## Overview

Data Prepper can derive metrics from OpenTelemetry trace spans using the `aggregate` processor.
Raw trace spans flow through a pipeline that groups them by identification keys (e.g., `serviceName`)
and computes aggregate metrics over configurable tumbling time windows.

## Pipeline Architecture

The pattern uses chained pipelines:

1. **entry-pipeline** — Receives OTel trace data via `otel_trace_source`, forwards to downstream pipelines.
2. **trace-to-metrics-pipeline** — Consumes from entry-pipeline, applies `aggregate` processor to derive metrics, sinks to an OpenSearch index (e.g., `metrics_for_traces`).

Optionally, a full trace analytics setup adds:
3. **raw-trace-pipeline** — Processes spans via `otel_traces` processor → `otel-v1-apm-span` index.
4. **service-map-pipeline** — Builds service dependency graphs via `service_map` processor → `otel-v1-apm-service-map` index.

## Derived Metric Types

The `aggregate` processor supports these actions relevant to trace-derived metrics:

| Action | Output | Use Case |
|---|---|---|
| **histogram** | Bucket counts, sum, count, min/max over a numeric key | Latency distribution (e.g., `durationInNanos` per service) |
| **count** | Event count per group (OTel SUM metric) | Request counts per service/endpoint |
| **rate_limiter** | Throttled event stream | Controlling throughput |
| **percent_sampler** | Sampled subset of events | Reducing volume while preserving distribution |

### Latency Histograms (Primary Use Case)

The documented example derives a histogram from `durationInNanos`, grouped by `serviceName`:
- Configurable bucket boundaries: `[0, 10000000, 50000000, 100000000]` (nanoseconds)
- `record_minmax: true` captures min/max latency per window
- `group_duration: "30s"` defines the tumbling window
- Output format defaults to OTel metrics (HISTOGRAM kind)

### Request Counts

Using the `count` action with `identification_keys: ["serviceName"]` produces per-service
request counts as OTel SUM metrics with `AGGREGATION_TEMPORALITY_DELTA`.

### Error Rates (Derived)

Error rates are not a built-in action but can be derived by:
- Using `identification_keys` that include status code or error fields from spans
- Combining `count` actions with conditional expressions to count error vs. total spans
- Span documents include `status.code` (0=OK, non-zero=error) and `traceGroupFields.statusCode`

## Key Configuration Parameters

```yaml
processor:
  - aggregate:
      identification_keys: ["serviceName"]  # Grouping dimensions
      action:
        histogram:
          key: "durationInNanos"             # Metric source field
          record_minmax: true                # Include min/max
          units: "seconds"                   # Unit label
          buckets: [0, 10000000, 50000000, 100000000]  # Bucket boundaries
      group_duration: "30s"                  # Aggregation window
```

## Relevance to Investigation Summaries

Trace-derived metrics serve as key inputs for automated investigation summaries:

1. **Latency histograms** → Identify p50/p95/p99 shifts, detect latency spikes per service
2. **Request counts** → Detect traffic anomalies (drops or surges) that correlate with incidents
3. **Service maps** → Reveal dependency chains; pinpoint which upstream/downstream service is degraded
4. **Error status codes** → `status.code` in span documents enables error rate computation per service

These metrics, stored in OpenSearch indexes, can be queried to:
- Establish baselines for anomaly detection
- Correlate latency changes with deployment events
- Build per-service health summaries as investigation context
- Feed into the `anomaly_detector` processor for automated alerting

## Span Document Structure (for downstream queries)

Key fields in `otel-v1-apm-span` index:
- `traceId`, `spanId`, `parentSpanId` — Trace correlation
- `serviceName` — Service identification
- `durationInNanos` — Span latency
- `status.code` — Error indicator (0 = OK)
- `traceGroupFields.statusCode` — Root span status
- `traceGroup` — Root span operation name
- `kind` — Span kind (CLIENT, SERVER, etc.)
