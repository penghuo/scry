Below is a revised English RFC draft that directly addresses the blocking review comments by adding concrete schemas, API shapes, end-to-end scenarios, a narrower P0, and a risks section. 
# RFC: OpenSearch Investigation Framework for Human and Agent Observability

## Status

Draft

## 1. Abstract

OpenSearch already has the foundations of an observability platform: OpenTelemetry-based trace ingestion, Data Prepper pipelines, Trace Analytics, Event Analytics, PPL, and agent/tool integration including MCP support. Trace Analytics is built on Data Prepper pipelines and service-map processing, Event Analytics is built on PPL, and OpenSearch agents/tools plus MCP already provide a programmatic integration surface. ([OpenSearch Documentation][1])

What OpenSearch does **not** currently provide is a first-class investigation model. Logs, metrics, traces, and agent events can be stored and queried, but the system does not provide stable objects for investigation entry, signal discovery, narrowing state, evidence sets, or conclusion state. This RFC proposes a concrete, implementable framework to add those capabilities **without redefining OpenTelemetry semantics**. OpenTelemetry semantic conventions already provide common names across traces, metrics, logs, profiles, and resources, and GenAI / agent conventions are evolving but remain in development. ([OpenTelemetry][2])

---

## 2. Problem Statement

Existing observability systems are organized around functional entry points: dashboards, search/query, trace exploration, log exploration, and alert investigation. That model is effective for interactive use, but it does not treat the investigation process itself as a first-class system capability. OpenSearch follows the same general model today: observability features exist, but they are organized around product surfaces rather than a reusable investigation state machine. ([OpenSearch Documentation][3])

The core problem is not that humans and agents investigate differently. The core problem is that both humans and agents must manually bridge several gaps:

1. **Entry and context convergence**
   An investigation rarely starts from zero. It starts from an alert, deployment, user report, anomalous trace, or other trigger. But today the system does not explicitly provide the structures needed to quickly answer: what object is under investigation, what signals exist for it, where those signals live, and what data is correlated.

2. **Cross-signal narrowing and prioritization**
   Investigation is not about seeing more data. It is about narrowing faster. The system must help move from metrics to traces to logs, compare candidate causes, and decide what to inspect next.

3. **Investigation state, evidence, and conclusion boundaries**
   Existing systems are good at storing raw telemetry and final query results. They are weak at expressing what has already been checked, what evidence exists, what was ruled out, and what level of conclusion is currently justified.

4. **Cross-system process semantics**
   As investigation spans multiple systems and tools, process objects such as task, step, evidence, action, and conclusion become inconsistent and hard to reuse programmatically.

These problems already exist for humans. They become more visible in agent-driven investigation because agents depend on explicit objects and APIs rather than informal UI-driven reasoning. OpenTelemetry has explicitly elevated AI agent observability as an area of active semantic work. ([OpenTelemetry][4])

---

## 3. Non-Goals

This RFC does **not** attempt to:

* redefine OpenTelemetry base semantics for service, instance, environment, trace, or span
* redesign the OpenSearch storage engine
* make sketch-based summaries a phase-1 dependency
* standardize all cross-vendor investigation semantics
* build a separate “agent-only” observability system

---

## 4. Current State

OpenSearch already provides the minimum technical substrate needed to implement an investigation framework:

* **OTel ingestion and Trace Analytics** via Data Prepper and Trace Analytics pipelines ([OpenSearch Documentation][1])
* **Service map generation** via the `service_map` / `otel_apm_service_map` processor ([OpenSearch Documentation][5])
* **PPL-based event analytics** for interactive analysis ([OpenSearch Documentation][6])
* **Aggregate processor support for counts and histograms** in Data Prepper today; this is important because it means Phase 1 can use derived metrics / histograms without waiting for sketch infrastructure ([OpenSearch Documentation][7])
* **Agent / tool / MCP integration surfaces** via ML Commons and MCP support ([OpenSearch Documentation][8])

The missing piece is not ingestion or query capability in isolation. The missing piece is a set of reusable **investigation objects** and **investigation APIs**.

---

## 5. Proposed Scope

Phase 1 introduces four concrete system objects and two concrete APIs.

### 5.1 Phase 1 objects

1. **Signal Catalog Record**
2. **Investigation Summary**
3. **Investigation Context**
4. **Evidence Set + Conclusion State**

### 5.2 Phase 1 APIs

1. `discover`
2. `narrow`

These are enough to implement a first end-to-end investigation loop.

---

## 6. Data Model

## 6.1 Signal Catalog Record

### Purpose

The signal catalog answers the first investigation question:

> For the current object, what signals exist, where are they stored, what time range is covered, and how can they be correlated?

### Schema

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

### Notes

* `object_key` reuses existing OTel identity fields where available. This RFC does not introduce mirror fields for `service`, `environment`, or `trace_id`. OpenTelemetry resource and semantic conventions remain the source of truth. ([OpenTelemetry][2])
* `source_locator` can point to an index pattern, alias, data source, or other OpenSearch-native read target.
* `resolution` is needed so investigation can distinguish raw data from histograms, derived metrics, and future sketch-based summaries.

---

## 6.2 Investigation Summary

### Purpose

An investigation summary provides **early narrowing evidence** without forcing every investigation step to rescan raw data.

### Phase 1 scope

Phase 1 supports only:

* `count`
* `histogram`
* `derived_metric`

This is deliberately aligned with what Data Prepper can already produce today. Sketches are deferred to P2. ([OpenSearch Documentation][7])

### Schema

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

### Notes

* This object is intentionally simple and aligned with Data Prepper’s aggregate processor output model. ([OpenSearch Documentation][7])
* Phase 2 may add `distinct_sketch`, `quantile_sketch`, and `heavy_hitter_summary`. Mergeable summaries are a good fit for distributed narrowing, but they are not a phase-1 dependency. ([DataSketches][9])

---

## 6.3 Investigation Context

### Purpose

Investigation context persists the state of the investigation itself.

### Schema

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

### State machine

Phase 1 supports five states:

* `open`
* `narrowed`
* `suspected`
* `inconclusive`
* `concluded`

This is directly motivated by the need to treat “inconclusive” as a first-class outcome rather than an implicit failure mode. That gap was explicitly identified in the review comments. 

---

## 6.4 Evidence Set

### Purpose

Evidence must be stored as a machine-readable object, not only as a UI rendering.

### Schema

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

### Why this is P0

The review correctly points out that machine-readable investigation state and evidence are the strongest differentiators and should not be delayed to P1. This RFC moves them into P0. 

---

## 7. API Specification

## 7.1 `discover`

### Purpose

Find all signals available for the current investigation scope.

### Request

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

### Response

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

### Semantics

`discover` answers the “where do I look?” question. It does not rank suspects and does not decide conclusions.

---

## 7.2 `narrow`

### Purpose

Use existing summaries to reduce search space before scanning raw telemetry.

### Request

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
    "signal_preference": ["trace", "metric"]
  }
}
```

### Response

```json
{
  "updated_state": "narrowed",
  "suspect_set": [
    {"kind": "deployment", "id": "deploy-2026-03-31", "reason": "latency_shift_after_deploy"},
    {"kind": "service", "id": "payment", "reason": "downstream_duration_tail"}
  ],
  "evidence_refs": [
    {"kind": "summary", "id": "sum-001"},
    {"kind": "summary", "id": "sum-002"}
  ],
  "next_actions": [
    {"kind": "pivot", "signal": "trace"},
    {"kind": "compare", "dimension": "deployment"}
  ]
}
```

### Semantics

`narrow` consumes summaries. It does not run final root-cause analysis. It produces:

* an updated investigation state
* a suspect set
* evidence references
* suggested next actions

---

## 8. End-to-End Scenarios

## Scenario A: Alert → Discover → Narrow

### A1. Alert fires

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

### A2. Discover

`discover(inv-123)` returns:

* trace source: `otel-v1-apm-span-*`
* metric source: `otel-v1-derived-metrics-*`
* log source: `app-logs-prod-*`

### A3. Narrow

`narrow(inv-123, strategy=latency_regression)` returns:

* suspect: `deploy-2026-03-31`
* suspect: downstream `payment`
* evidence refs: latency histogram summaries
* state transitions `open → narrowed`

### A4. Follow-up

A later query step may pivot to raw traces or logs, but the investigation has already moved from “which data should I inspect?” to “which candidate should I inspect next?”

This directly addresses Sections 2.1 and 2.2.

---

## Scenario B: Agent-driven investigation

### B1. Agent asks for available signals

Agent calls `discover` for:

```json
{
  "service_name": "checkout",
  "environment": "prod"
}
```

### B2. Agent gets machine-readable response

The response tells the agent:

* where metrics live
* where traces live
* where logs live
* what time coverage exists
* what correlation keys exist

### B3. Agent calls `narrow`

The agent gets:

* suspect set
* evidence refs
* updated state
* recommended next actions

### B4. Agent stores evidence-backed reasoning state

Because the state and evidence are machine-readable, the agent does not need to reconstruct investigation history from raw pages or ad hoc notes.

This directly addresses Sections 2.1, 2.2, and 2.3.

---

## 9. How the Solution Resolves the Earlier Problems

| Problem                                                         | Solution                                                 | Resolution                                                                                                          |
| --------------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Investigation entry, object identification, context convergence | Signal catalog + investigation context                   | Makes signals discoverable and scope explicit                                                                       |
| Cross-signal narrowing and prioritization                       | Investigation summaries + `narrow` API                   | Enables early narrowing before raw scans                                                                            |
| Investigation state, evidence, and conclusion boundaries        | Investigation context + evidence set + conclusion states | Makes state and evidence explicit and reusable                                                                      |
| Cross-system process semantics                                  | Shared investigation objects + APIs                      | Provides a concrete OpenSearch-side process model, even if broader cross-vendor standardization remains future work |

---

## 10. Priorities

### P0

* Signal catalog
* Investigation summaries using existing histograms / derived metrics
* Investigation context
* Evidence set
* Conclusion state
* `discover` API
* `narrow` API

### P1

* `pivot`, `compare`, `continue` APIs
* entry context enrichment
* MCP-oriented exposure of investigation APIs

### P2

* mergeable sketches
* broader agent telemetry alignment
* richer governance rules and broader cross-system semantics

This is intentionally narrower than the earlier draft. The review was correct that sketches should not block P0 and that machine-readable evidence/state should be P0. 

---

## 11. Risks and Mitigations

### Risk 1: Added complexity

Users already cite observability complexity as a major obstacle, and the review correctly notes that this RFC could add new concepts. 

**Mitigation:**
Phase 1 introduces only four persisted objects and two APIs. It does not require a new UI-first framework, and it reuses current OpenSearch ingestion, analytics, and agent surfaces.

### Risk 2: Foundation gaps in OpenSearch observability

Current trace analytics and observability features are incomplete relative to more mature platforms. The review is right that the framework must not assume missing foundations are already solved. 

**Mitigation:**
Phase 1 depends only on existing OTel ingestion, Data Prepper pipelines, histograms / counts, and current analytics read paths.

### Risk 3: Baggage security

OTel baggage is plaintext and propagates broadly. The review correctly points out that this is risky for investigation context. 

**Mitigation:**
Entry context enrichment is optional, not required for Phase 1, and must be limited to non-sensitive identifiers.

### Risk 4: Weak adoption if this feels like “another framework”

The review correctly challenges whether industry consolidation trends make another abstraction layer undesirable. 

**Mitigation:**
This RFC is not a new product layer. It is a reuse-oriented system model that consolidates existing OpenSearch observability and agent integration paths into explicit investigation objects and APIs.

---

## 12. Appendix: Standards Boundary

### Reuse from OpenTelemetry

* service identity
* instance identity
* deployment environment
* trace / span correlation
* evolving GenAI / agent semantic conventions

### OpenSearch-specific additions

* signal catalog
* investigation summaries
* investigation context
* evidence set
* conclusion state
* investigation APIs

The boundary is simple: OpenTelemetry remains the source of truth for telemetry semantics; OpenSearch adds the investigation organization layer.

---

If you want, I can next turn this revised English RFC into a cleaner review-ready format with:

* shorter section titles,
* tighter normative language using MUST/SHOULD/MAY,
* and a markdown table for the exact P0 schema contracts.

[1]: https://docs.opensearch.org/latest/data-prepper/common-use-cases/trace-analytics/?utm_source=chatgpt.com "Trace analytics"
[2]: https://opentelemetry.io/docs/concepts/semantic-conventions/?utm_source=chatgpt.com "Semantic Conventions"
[3]: https://docs.opensearch.org/latest/observing-your-data/?utm_source=chatgpt.com "Observability"
[4]: https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-agent-spans/?utm_source=chatgpt.com "Semantic Conventions for GenAI agent and framework spans"
[5]: https://docs.opensearch.org/latest/data-prepper/pipelines/configuration/processors/service-map/?utm_source=chatgpt.com "Service map processor"
[6]: https://docs.opensearch.org/latest/observing-your-data/event-analytics/?utm_source=chatgpt.com "Event analytics"
[7]: https://docs.opensearch.org/latest/data-prepper/pipelines/configuration/processors/aggregate/?utm_source=chatgpt.com "Aggregate processor"
[8]: https://docs.opensearch.org/latest/ml-commons-plugin/agents-tools/index/?utm_source=chatgpt.com "Agents and tools"
[9]: https://datasketches.apache.org/docs/Community/Research.html?utm_source=chatgpt.com "DataSketches Research Directions"
