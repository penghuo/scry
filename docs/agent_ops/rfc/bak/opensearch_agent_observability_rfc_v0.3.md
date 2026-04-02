# RFC: OpenSearch Investigation Framework for Human and Agent Observability

## Status

Draft

## 1. Summary

OpenSearch already provides the core building blocks of an observability platform: OTel-based ingestion, Data Prepper pipelines, Trace Analytics, Event Analytics, PPL, and agent / tool integration including MCP support. Trace Analytics depends on Data Prepper trace pipelines and service-map generation. Data Prepper already supports aggregate processing, including counts and explicit-boundary histograms. OpenSearch also exposes agent and MCP integration surfaces through ML Commons.

What OpenSearch does **not** currently provide is a first-class investigation model. Logs, metrics, traces, and agent events can be stored and queried, but the system does not provide stable objects for signal discovery, early narrowing, investigation state, evidence sets, or conclusion state.

This RFC introduces a minimal investigation framework on top of the existing OpenSearch observability stack. Phase 1 adds four persisted objects and two APIs.

**Objects**
1. Signal Catalog Record
2. Investigation Summary
3. Investigation Context
4. Evidence Set

**APIs**
1. `discover`
2. `narrow`

The goal is not to redefine telemetry semantics. OpenTelemetry remains the source of truth for base service, resource, environment, trace, and span semantics. This RFC adds an OpenSearch-specific investigation organization layer above those foundations. OpenTelemetry also has **development-status** semantic conventions for GenAI / agent spans, which this RFC reuses where applicable rather than redefining.

## 2. Problem Statement

Existing observability systems are organized around functional entry points: dashboards, search/query, trace exploration, log exploration, and alert investigation. This model works for interactive use, but it does not treat the investigation process itself as a first-class system capability. OpenSearch follows the same general pattern today: observability capabilities exist, but they are organized around product surfaces rather than a reusable investigation workflow.

Humans and agents generally investigate incidents in similar ways: observe the anomaly, narrow scope, compare candidates, gather evidence, and then decide whether to act. The problem is not that agents use a different method. The problem is that most of the investigation process still has to be stitched together manually across tools, data sources, and signals.

This creates four direct gaps.

### 2.1 Investigation entry, object identification, and context convergence are weak

An investigation rarely starts from zero. It starts from an alert, deployment, user report, anomalous trace, or similar trigger. Today the system does not explicitly provide the structures needed to answer:

- what object is under investigation
- what signals exist for that object
- where those signals live
- what data is correlated

Humans and agents do not naturally know where metrics, logs, and traces are, nor how they relate. They depend on the system to make investigation objects, data locations, relationships, and entry context explicit.

### 2.2 Cross-signal narrowing and candidate prioritization are weak

Investigation is not about looking at more data. It is about narrowing faster. Real investigations move across metrics, traces, logs, deployments, and dependencies to identify which system, dimension, or time window is most likely involved.

Another key step is candidate prioritization. Engineers must decide whether to inspect a deployment, downstream service, tenant, or path first. Today this is still largely a manual comparison process.

### 2.3 Investigation state, evidence, and conclusion boundaries are weak

Most observability systems are good at storing raw telemetry and final query results. They are weak at expressing:

- what has already been checked
- which hypotheses were formed
- what was ruled out
- where the evidence chain stands
- what level of conclusion is currently justified

Investigation does not always produce a certain root cause. `inconclusive` is often a valid outcome and needs to be represented explicitly.

### 2.4 Cross-system process semantics are inconsistent

As investigation spans multiple systems and tools, process objects such as task, step, evidence, and action become inconsistent. That makes reuse, audit, and automation harder.

## 3. Goals

Phase 1 goals are:

1. make available signals discoverable for a given investigation scope
2. provide early narrowing inputs without rescanning all raw telemetry
3. persist investigation state and evidence as machine-readable objects
4. expose those objects through stable APIs
5. make `inconclusive` a first-class outcome

## 4. Non-Goals

This RFC does **not** attempt to:

- redefine OTel base semantics
- redesign the OpenSearch storage engine
- make sketch-based summaries a phase-1 dependency
- standardize all cross-vendor investigation semantics
- build a separate agent-only observability system
- solve all UI flows in phase 1

## 5. Current State

OpenSearch already has the minimum technical substrate required for a phase-1 investigation framework:

- **OTel ingestion and Trace Analytics** through Data Prepper and trace pipelines
- **service map generation** through Data Prepper service-map processors
- **PPL-based event analytics** for interactive analysis
- **Aggregate processor support for counts and explicit-boundary histograms** in Data Prepper today. This matters because Phase 1 can use derived metrics and histograms without depending on sketch infrastructure.
- **Agent / tool / MCP integration surfaces** through ML Commons and MCP support

The missing piece is not ingestion or query capability in isolation. The missing piece is a set of reusable investigation objects and investigation APIs.

## 6. Design Principles

### 6.1 Center the design on the investigation path

Prioritize capabilities that improve the investigation path, not isolated feature enhancement.

### 6.2 Prioritize shared capabilities for humans and agents

First close the gaps in object identification, signal discovery, narrowing, state expression, and boundary expression that both humans and agents need. Then add agent-oriented consumption patterns.

### 6.3 Make process explicit, not just results

The system must represent checked scope, suspect sets, evidence sets, conclusion state, and next step, not only raw hits or final charts.

### 6.4 Prefer programmatic consumption

UI remains important, but core investigation objects and states must not live only in page interactions.

### 6.5 Make evidence, conclusion, and action boundaries explicit

The system must distinguish between leads, evidence, supported conclusions, and which conclusions are eligible for follow-on action.

### 6.6 Evolve incrementally on existing OpenSearch and OTel capabilities

Do not redefine OTel fundamentals. Reuse Data Prepper, Trace Analytics, PPL, MCP, and related capabilities. Add an investigation organization layer above them.

## 7. Proposed Scope

Phase 1 introduces four concrete system objects and two concrete APIs.

### 7.1 Phase 1 objects

1. Signal Catalog Record
2. Investigation Summary
3. Investigation Context
4. Evidence Set

### 7.2 Phase 1 APIs

1. `discover`
2. `narrow`

These are sufficient to implement a first end-to-end investigation loop.

## 8. Data Model

### 8.1 Signal Catalog Record

Purpose: answer the first investigation question: for the current object, what signals exist, where are they stored, what time range is covered, and how can they be correlated.

Schema:

```json
{
  "object_key": {
    "service_name": "checkout",
    "environment": "prod",
    "instance_id": "i-123",
    "deployment_id": "deploy-2026-03-31"
  },
  "signal_type": "trace",
  "source_locator": {
    "kind": "index_pattern",
    "value": "otel-v1-apm-span-*"
  },
  "time_coverage": {
    "start": "2026-03-31T00:00:00Z",
    "end": "2026-03-31T23:59:59Z"
  },
  "correlation_keys": [
    "service.name",
    "trace_id",
    "span_id"
  ],
  "resolution": "raw",
  "freshness_ts": "2026-03-31T23:59:59Z"
}
```

Notes:

- `object_key` reuses existing OTel identity where available.
- `source_locator` points to an index pattern, alias, or other read target.
- `resolution` distinguishes raw data from derived metrics, histograms, and future sketch-based summaries.

### 8.2 Investigation Summary

Purpose: provide early narrowing evidence without forcing every investigation step to rescan raw data.

Phase 1 supports only:

- `count`
- `histogram`
- `derived_metric`

This is intentionally aligned with what Data Prepper can already produce today. Sketches are deferred to P2.

Schema:

```json
{
  "summary_id": "sum-001",
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:05:00Z"
  },
  "source_signal": "trace",
  "summary_type": "histogram",
  "metric_name": "duration_ms",
  "payload": {
    "count": 12453,
    "sum": 9812334,
    "min": 12,
    "max": 9421,
    "buckets": [
      {"le": 100, "count": 7000},
      {"le": 500, "count": 11000},
      {"le": 1000, "count": 12100},
      {"le": 5000, "count": 12420}
    ]
  },
  "provenance": {
    "pipeline": "trace-aggregate",
    "materialized_from": "otel-v1-apm-span-*"
  },
  "freshness_ts": "2026-03-31T10:05:10Z"
}
```

### 8.3 Investigation Context

Purpose: persist the state of the investigation itself.

Schema:

```json
{
  "investigation_id": "inv-123",
  "entry": {
    "type": "alert",
    "id": "alert-456"
  },
  "scope": {
    "object_key": {
      "service_name": "checkout",
      "environment": "prod"
    },
    "time_window": {
      "start": "2026-03-31T10:00:00Z",
      "end": "2026-03-31T10:30:00Z"
    }
  },
  "checked_signals": ["metric", "trace"],
  "suspect_set": [
    {"kind": "deployment", "id": "deploy-2026-03-31"},
    {"kind": "service", "id": "payment"}
  ],
  "state": "narrowed",
  "last_updated": "2026-03-31T10:07:00Z"
}
```

State machine:

- `open`
- `narrowed`
- `suspected`
- `inconclusive`
- `concluded`

Valid transitions:

| From | To | Trigger |
|---|---|---|
| `open` | `narrowed` | `narrow` returns non-empty `suspect_set` |
| `open` | `inconclusive` | `discover` or `narrow` returns no usable data |
| `narrowed` | `suspected` | follow-up analysis identifies one dominant suspect with supporting evidence |
| `narrowed` | `inconclusive` | all candidates exhausted or evidence remains insufficient |
| `suspected` | `concluded` | conclusion explicitly finalized with evidence-backed state |
| `suspected` | `inconclusive` | conflicting evidence or insufficient follow-up evidence |

Invalid transitions in Phase 1:

- `open -> concluded`
- `open -> suspected`
- `inconclusive -> narrowed`
- `concluded -> any`

`inconclusive` and `concluded` are terminal states in Phase 1.

### 8.4 Evidence Set

Purpose: store evidence as a machine-readable object, not only as a UI rendering.

Schema:

```json
{
  "evidence_id": "ev-001",
  "investigation_id": "inv-123",
  "evidence_type": "supporting_histogram",
  "related_object": {
    "kind": "deployment",
    "id": "deploy-2026-03-31"
  },
  "supporting_signals": ["trace", "metric"],
  "supporting_refs": [
    {"kind": "summary", "id": "sum-001"},
    {"kind": "query_result", "id": "qr-778"}
  ],
  "confidence": "medium",
  "completeness": "partial",
  "conclusion_impact": "supports_suspect"
}
```

Allowed values:

- `confidence`: `low | medium | high`
- `completeness`: `partial | substantial | complete`
- `conclusion_impact`: `none | supports_suspect | rejects_suspect | supports_conclusion`

## 9. Storage Specification

### 9.1 Physical storage

Phase 1 stores the investigation objects in OpenSearch-managed indexes.

| Object | Storage | Naming | Retention | Notes |
|---|---|---|---|---|
| Signal Catalog Record | system index | `.investigation-catalog-v1` | 30 days after `freshness_ts` | upsert by `(object_key, signal_type, source_locator)` |
| Investigation Summary | time-partitioned system index | `.investigation-summary-v1-YYYY.MM.DD` | 14 days default | immutable after write |
| Investigation Context | system index | `.investigation-context-v1` | 90 days after terminal state | update by ID |
| Evidence Set | system index | `.investigation-evidence-v1` | 90 days after terminal state | append-only |

### 9.2 Access control

- Direct index access is not required for normal users.
- Phase 1 access is through investigation APIs.
- Administrative and debugging access may be granted to privileged roles.

These objects do not replace raw logs, traces, or metrics. Signal catalog and summaries are read-optimized support objects. Context and evidence are state objects.

## 10. API Specification

### 10.1 `discover`

Purpose: find all signals available for the current investigation scope.

Request:

```json
POST /_plugins/_investigation/discover
{
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  }
}
```

Success with matches:

```json
{
  "catalog_records": [
    {
      "signal_type": "trace",
      "source_locator": {"kind": "index_pattern", "value": "otel-v1-apm-span-*"},
      "time_coverage": {
        "start": "2026-03-31T10:00:00Z",
        "end": "2026-03-31T10:30:00Z"
      },
      "correlation_keys": ["service.name", "trace_id", "span_id"],
      "resolution": "raw"
    },
    {
      "signal_type": "metric",
      "source_locator": {"kind": "index_pattern", "value": "otel-v1-derived-metrics-*"},
      "time_coverage": {
        "start": "2026-03-31T10:00:00Z",
        "end": "2026-03-31T10:30:00Z"
      },
      "correlation_keys": ["service.name"],
      "resolution": "derived_metric"
    }
  ]
}
```

Success with no matches:

```json
{
  "catalog_records": [],
  "empty_reason": "no_signals_found"
}
```

Invalid request:

```json
{
  "error_code": "invalid_request",
  "message": "object_key.service_name is required"
}
```

### 10.2 `narrow`

Purpose: use existing summaries to reduce search space before scanning raw telemetry.

Phase 1 supports exactly two strategies.

| strategy.kind | Input required | Baseline | Output intent |
|---|---|---|---|
| `latency_regression` | histogram or derived metric summaries for latency-like metrics | immediately preceding equal-length time window | identify suspects associated with latency shift |
| `error_spike` | count or derived metric summaries for error and request totals | immediately preceding equal-length time window | identify suspects associated with error-rate increase |

Any other value is invalid in Phase 1.

#### `latency_regression`

Consumes:

- `summary_type in {histogram, derived_metric}`
- `metric_name in {"duration_ms", "latency_ms", "request_latency_ms"}`

Algorithm:

1. Select current-window summaries for the requested object scope.
2. Select the immediately preceding equal-length baseline window.
3. Generate candidate dimensions in this order when available:
   - `deployment_id`
   - downstream `service_name`
   - `tenant`
4. Compute candidate score using:
   - tail shift if histogram exists
   - average or rate delta if only derived metric exists
5. Discard candidates below `min_volume` and `min_delta_threshold`.
6. Return remaining candidates as ranked `suspect_set`.

Request:

```json
POST /_plugins/_investigation/narrow
{
  "investigation_id": "inv-123",
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  },
  "strategy": {
    "kind": "latency_regression",
    "min_volume": 100,
    "min_delta_threshold": 0.20
  }
}
```

#### `error_spike`

Consumes:

- `summary_type in {count, derived_metric}`
- error count and total request count for the same scope

Algorithm:

1. Select current-window summaries.
2. Select the immediately preceding equal-length baseline.
3. Compute error-rate delta by candidate dimension.
4. Rank candidates by descending error-rate increase.
5. Discard candidates below `min_volume` and `min_delta_threshold`.

Request:

```json
POST /_plugins/_investigation/narrow
{
  "investigation_id": "inv-789",
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  },
  "strategy": {
    "kind": "error_spike",
    "min_volume": 50,
    "min_delta_threshold": 0.10
  }
}
```

Success with suspects:

```json
{
  "updated_state": "narrowed",
  "suspect_set": [
    {
      "kind": "deployment",
      "id": "deploy-2026-03-31",
      "reason": "error_rate_increase_after_deploy"
    },
    {
      "kind": "service",
      "id": "payment",
      "reason": "downstream_error_correlation"
    }
  ],
  "evidence_refs": [
    {"kind": "summary", "id": "sum-err-001"},
    {"kind": "summary", "id": "sum-err-002"}
  ],
  "next_actions": [
    {"kind": "pivot", "signal": "trace"},
    {"kind": "compare", "dimension": "deployment"}
  ]
}
```

Success with no usable summaries:

```json
{
  "updated_state": "inconclusive",
  "suspect_set": [],
  "evidence_refs": [],
  "next_actions": [],
  "empty_reason": "no_summaries_available"
}
```

Investigation not found:

```json
{
  "error_code": "investigation_not_found",
  "message": "investigation_id inv-123 does not exist"
}
```

Invalid strategy:

```json
{
  "error_code": "invalid_strategy",
  "message": "strategy.kind must be one of latency_regression,error_spike"
}
```

## 11. End-to-End Scenarios

### 11.1 Scenario A: Alert-driven investigation

#### A1. Alert fires

Alert: `checkout latency p95 high`

System creates:

```json
{
  "investigation_id": "inv-123",
  "entry": {"type": "alert", "id": "alert-456"},
  "scope": {
    "object_key": {"service_name": "checkout", "environment": "prod"},
    "time_window": {
      "start": "2026-03-31T10:00:00Z",
      "end": "2026-03-31T10:30:00Z"
    }
  },
  "state": "open"
}
```

#### A2. Discover

`discover(inv-123)` returns:

- trace source: `otel-v1-apm-span-*`
- metric source: `otel-v1-derived-metrics-*`
- log source: `app-logs-prod-*`

#### A3. Narrow

`narrow(inv-123, strategy=latency_regression)` returns:

- suspect: `deploy-2026-03-31`
- suspect: downstream `payment`
- evidence refs: latency histogram summaries
- state transition: `open -> narrowed`

#### A4. Follow-up

A later query may pivot to raw traces or logs, but the investigation has already moved from “which data should I inspect?” to “which candidate should I inspect next?”

### 11.2 Scenario B: Agent-driven investigation

#### B1. Agent calls `discover`

```json
POST /_plugins/_investigation/discover
{
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  }
}
```

#### B2. System returns available signals

```json
{
  "catalog_records": [
    {
      "signal_type": "trace",
      "source_locator": {
        "kind": "index_pattern",
        "value": "otel-v1-apm-span-*"
      },
      "time_coverage": {
        "start": "2026-03-31T10:00:00Z",
        "end": "2026-03-31T10:30:00Z"
      },
      "correlation_keys": ["service.name", "trace_id", "span_id"],
      "resolution": "raw"
    },
    {
      "signal_type": "metric",
      "source_locator": {
        "kind": "index_pattern",
        "value": "otel-v1-derived-metrics-*"
      },
      "time_coverage": {
        "start": "2026-03-31T10:00:00Z",
        "end": "2026-03-31T10:30:00Z"
      },
      "correlation_keys": ["service.name"],
      "resolution": "derived_metric"
    }
  ]
}
```

#### B3. Agent calls `narrow`

```json
POST /_plugins/_investigation/narrow
{
  "investigation_id": "inv-789",
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  },
  "strategy": {
    "kind": "error_spike",
    "min_volume": 50,
    "min_delta_threshold": 0.10
  }
}
```

#### B4. System returns suspects and machine-readable evidence

```json
{
  "updated_state": "narrowed",
  "suspect_set": [
    {
      "kind": "deployment",
      "id": "deploy-2026-03-31",
      "reason": "error_rate_increase_after_deploy"
    },
    {
      "kind": "service",
      "id": "payment",
      "reason": "downstream_error_correlation"
    }
  ],
  "evidence_refs": [
    {"kind": "summary", "id": "sum-err-001"},
    {"kind": "summary", "id": "sum-err-002"}
  ],
  "next_actions": [
    {"kind": "pivot", "signal": "trace"},
    {"kind": "compare", "dimension": "deployment"}
  ]
}
```

Because the state and evidence are machine-readable, the agent does not need to reconstruct investigation history from raw pages or ad hoc notes.

## 12. Why This Matters

This is not only an internal cleanup. It is a product differentiator.

As noted in review, Datadog Bits AI SRE exposes investigation primarily through UI flows. The current gap is the lack of a formal, machine-readable evidence contract and programmatic investigation state API. OpenSearch can differentiate by making investigation state, evidence, and narrowing outputs first-class API objects from Phase 1 rather than UI-only artifacts.

## 13. How the Solution Resolves the Earlier Problems

| Problem | Solution | Resolution |
|---|---|---|
| Investigation entry, object identification, context convergence | Signal catalog + investigation context | Makes signals discoverable and scope explicit |
| Cross-signal narrowing and prioritization | Investigation summaries + `narrow` API | Enables early narrowing before raw scans |
| Investigation state, evidence, conclusion boundaries | Investigation context + evidence set + conclusion states | Makes state and evidence explicit and reusable |
| Cross-system process semantics | Shared investigation objects + APIs | Provides a concrete OpenSearch-side process model, even if broader cross-vendor standardization remains future work |

## 14. Rollout

### P0

- Signal catalog
- Investigation summaries using existing histograms / derived metrics
- Investigation context
- Evidence set
- Conclusion state
- `discover` API
- `narrow` API

### P1

- `pivot`, `compare`, `continue` APIs
- entry context enrichment
- MCP-oriented exposure of investigation APIs

### P2

- mergeable sketches
- broader agent telemetry alignment
- richer governance rules and broader cross-system semantics

This order is deliberate. P0 establishes the minimum closed loop for investigation: discover, pre-narrow, store state, and store evidence. P1 makes that loop richer and more agent-friendly. P2 adds capabilities that require more infrastructure or broader semantic alignment.

## 15. Risks and Mitigations

### 15.1 Added complexity

This risk is real. Industry data points toward consolidation, and complexity is itself a major obstacle in observability. The danger is that this RFC could look like another abstraction layer.

Mitigation:

- Phase 1 is intentionally narrow: four persisted objects and two APIs.
- It does not introduce a new end-user product surface.
- It externalizes investigation structures that already exist implicitly across OpenSearch observability, notebooks, assistant flows, and agent/tool integrations.
- The design goal is to reduce hidden investigation complexity, not add a second control plane.

### 15.2 Foundation gaps in OpenSearch observability

Current trace analytics and observability features are not as broad as more mature integrated platforms. The framework must not assume missing foundations are already solved.

Mitigation:

- Phase 1 depends only on existing OTel ingestion, Data Prepper pipelines, counts / histograms, and current analytics read paths.
- Sketches are explicitly deferred to P2.

### 15.3 Baggage security

OTel baggage is plaintext and propagates broadly. Investigation context carried that way can leak if used carelessly.

Mitigation:

- Entry context enrichment is optional, not required for Phase 1.
- It must be limited to non-sensitive identifiers.

### 15.4 Concurrent access

Multiple humans or agents may act on the same investigation.

Mitigation:

- `Investigation Context` is update-by-ID.
- Phase 1 should use optimistic concurrency control on state updates.
- Terminal states are immutable.

## 16. Standards Boundary

### Reuse from OpenTelemetry

- service identity
- instance identity
- deployment environment
- trace / span correlation
- development-status GenAI / agent semantic conventions

### OpenSearch-specific additions

- signal catalog
- investigation summaries
- investigation context
- evidence set
- conclusion state
- investigation APIs

The boundary is simple: OpenTelemetry remains the source of truth for telemetry semantics; OpenSearch adds the investigation organization layer.
