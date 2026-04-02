# DataSketches Integration Design for OpenSearch Agent Observability

## 1. Architecture Overview

Two-layer design following Druid's dual-mode pattern. The existing `cardinality` agg (HLL++ internally) proves the shard-then-reduce sketch pattern already works in OpenSearch.

```
Layer 1 (Ingestion): Data Prepper sketch_aggregate AggregateAction
  OTel signals → group by service/window → BUILD sketches → emit Base64 bytes → OpenSearch

Layer 2 (Query): OpenSearch SearchPlugin.getAggregations() SPI
  Query → per-shard SketchBuild|SketchMerge → coordinator reduce() via union → estimate|sketch
```

| Layer | Extension Point | Mode |
|-------|----------------|------|
| Data Prepper | `AggregateAction` | BUILD from raw events, streaming windows |
| OpenSearch | `SearchPlugin.getAggregations()` | BUILD from raw docs OR MERGE stored sketches |

## 2. Data Prepper Integration

### 2.1 AggregateAction Core Logic
```java
public class SketchAggregateAction implements AggregateAction {
    public AggregateActionResponse handleEvent(Event event, AggregateActionInput input) {
        getOrCreate(input, "latency_kll", () -> KllDoublesSketch.newHeapInstance(200))
            .update(event.get("duration_ms", Double.class));
        getOrCreate(input, "trace_id_hll", () -> new HllSketch(12))
            .update(event.get("trace_id", String.class));
        return AggregateActionResponse.nullEventResponse();
    }
    public Optional<AggregateActionOutput> concludeGroup(AggregateActionInput input) {
        Event out = buildEvent(input);
        out.put("latency_kll", Base64.encode(latencySketch.toByteArray()));
        out.put("trace_id_hll", Base64.encode(cardSketch.toCompactByteArray()));
        return Optional.of(new AggregateActionOutput(List.of(out)));
    }
}
```

### 2.2 Pipeline Configuration
```yaml
sketch-pipeline:
  source:
    otel_trace_source: { ssl: false }
  processor:
    - sketch_aggregate:
        identification_keys: ["service.name", "operation"]
        group_duration: "60s"
        sketches:
          - { name: latency_kll,    type: kll_doubles,      k: 200,              source_field: duration_ms }
          - { name: trace_id_hll,   type: hll,              lgk: 12,             source_field: trace_id }
          - { name: user_id_theta,  type: theta,            nominal_entries: 4096, source_field: user_id }
          - { name: error_code_freq, type: frequent_items,  max_map_size: 2048,  source_field: error.code }
  sink:
    - opensearch: { index: "investigation-sketches-%{yyyy.MM.dd}" }
```

### 2.3 Sketch Selection by Signal Type

| Signal | Sketch | Source Field | Investigation Use |
|--------|--------|-------------|-------------------|
| Traces | KLL | `duration_ms` | Latency percentiles (narrow) |
| Traces | HLL | `trace_id` | Request cardinality (discover) |
| Traces | Theta | `user_id` | User set ops (pivot/compare) |
| Metrics | KLL | `value` | Value distribution (narrow) |
| Logs | HLL | `error.code` | Unique error count (discover) |
| Logs | FreqItems | `error.message` | Top errors (discover/narrow) |

## 3. OpenSearch Storage

```json
{
  "mappings": {
    "properties": {
      "service_name":    { "type": "keyword" },
      "operation":       { "type": "keyword" },
      "window_start":    { "type": "date" },
      "window_end":      { "type": "date" },
      "latency_kll":     { "type": "binary", "doc_values": true },
      "trace_id_hll":    { "type": "binary", "doc_values": true },
      "user_id_theta":   { "type": "binary", "doc_values": true },
      "error_code_freq": { "type": "binary", "doc_values": true },
      "sketch_metadata": {
        "properties": {
          "sketch_type":   { "type": "keyword" },
          "k_parameter":   { "type": "integer" },
          "source_signal": { "type": "keyword" },
          "item_count":    { "type": "long" }
        }
      }
    }
  }
}
```

Each document = one group × one time window. Sketch bytes as `binary` with `doc_values: true` for aggregation access.

## 4. OpenSearch Query-Time Aggregation Plugin

### 4.1 Plugin + Dual Aggregator Pattern (following Druid)

```java
public class DataSketchesPlugin extends Plugin implements SearchPlugin {
    @Override
    public List<AggregationSpec> getAggregations() {
        return List.of(
            new AggregationSpec(SketchBuildAggregationBuilder.NAME, SketchBuildAggregationBuilder::new, SketchBuildAggregationBuilder::parse),
            new AggregationSpec(SketchMergeAggregationBuilder.NAME, SketchMergeAggregationBuilder::new, SketchMergeAggregationBuilder::parse));
    }
}
```

| Aggregator | Input | Output | Use Case |
|-----------|-------|--------|----------|
| `sketch_build` | Raw field values | Sketch bytes | Query-time sketch from raw docs |
| `sketch_merge` | Binary sketch field | Merged sketch | Merge pre-built sketches |

### 4.2 Coordinator Merge — `InternalAggregation.reduce()`

Universal pattern: deserialize each shard's sketch → union → re-serialize. HLL uses `Union.update()`, KLL uses `sketch.merge()`, Theta uses `SetOperation.builder().buildUnion()`, FreqItems uses `sketch.merge()`.

### 4.3 Query DSL

```json
// SketchMerge: merge pre-built sketches, finalize to quantiles
{ "aggs": { "latency": { "sketch_merge": {
    "field": "latency_kll", "sketch_type": "kll_doubles",
    "finalize": { "quantiles": [0.5, 0.95, 0.99] } } } } }

// SketchBuild: build from raw values, finalize to estimate
{ "aggs": { "users": { "sketch_build": {
    "field": "user_id", "sketch_type": "hll", "lgk": 12,
    "finalize": "estimate" } } } }
```

Omit `finalize` → returns Base64 intermediate sketch for further composition.

## 5. PPL Integration

### 5.1 Function → Primitive Mapping

| PPL Function | Sketch | RFC Primitive | Returns |
|-------------|--------|---------------|---------|
| `sketch_count_distinct(field)` | HLL | discover | `LONG` |
| `sketch_percentile(field, p)` | KLL | narrow | `DOUBLE` |
| `sketch_intersect(a, b)` | Theta | compare | `BINARY` |
| `sketch_diff(a, b)` | Theta AnotB | pivot | `BINARY` |
| `sketch_merge(field)` | Union any | aggregate | `BINARY` |
| `sketch_top_k(field, k)` | FreqItems | discover | `ARRAY<STRUCT>` |
| `sketch_estimate(sketch)` | Any→scalar | finalize | `DOUBLE` |

### 5.2 PPL Examples by Primitive

**discover**: `source=traces | where service.name="checkout-service" AND status.code="ERROR" | stats sketch_count_distinct(user_id) as affected`

**narrow**: `source=traces | where service.name="checkout-service" | stats sketch_percentile(duration_ms, 99) as p99 by host.name | where p99 > 2000`

**pivot** (new errors post-deploy):
```sql
source = investigation-sketches-*
| where service_name = "checkout-service"
| eval baseline = sketch_merge(user_id_theta) FILTER(window_end < "2025-01-15T10:00:00Z")
| eval current  = sketch_merge(user_id_theta) FILTER(window_start >= "2025-01-15T10:00:00Z")
| eval new_users = sketch_diff(current, baseline)
| eval new_count = sketch_estimate(new_users)
```

**compare** (overlap between error users and deploy-window users):
```sql
source = investigation-sketches-*
| where service_name = "checkout-service"
| eval error_users  = sketch_merge(user_id_theta) FILTER(status.code = "ERROR")
| eval deploy_users = sketch_merge(user_id_theta) FILTER(window_start >= deploy_time)
| eval overlap = sketch_intersect(error_users, deploy_users)
| stats sketch_estimate(overlap) as shared, sketch_estimate(sketch_diff(error_users, deploy_users)) as error_only
```

## 6. MCP Tool Surface

Four tools mapping 1:1 to investigation primitives. Each wraps PPL/DSL queries.

| MCP Tool | Sketch | Input | Output |
|----------|--------|-------|--------|
| `sketch_discover` | HLL | index, field, filter, time_range | estimate, lower_bound, upper_bound, rse |
| `sketch_narrow` | KLL | index, field, percentiles[], filter, time_range, group_by? | {dimension → {p50, p95, p99}} |
| `sketch_pivot` | Theta | index, field, current_filter, baseline_filter, time_range | new_count, removed_count, jaccard |
| `sketch_compare` | Theta | index, field, set_a, set_b, time_range | intersection_count, a_only, b_only, jaccard |

All tools accept standard OpenSearch query filters and ISO time ranges. Output always includes error bounds.

## 7. End-to-End Walkthrough: p99 Spike on checkout-service After Deploy

**Step 1 — discover (HLL)**: "How many users affected?"
```sql
source=investigation-sketches-* | where service_name="checkout-service" AND window_start>="2025-01-15T10:00:00Z"
| stats sketch_count_distinct(user_id_theta) as affected
```
→ `affected: 12,847 (±167)` — significant blast radius.

**Step 2 — narrow (KLL)**: "Which hosts? What percentile range?"
```sql
source=investigation-sketches-* | where service_name="checkout-service" AND window_start>="2025-01-15T10:00:00Z"
| stats sketch_percentile(latency_kll, 50) as p50, sketch_percentile(latency_kll, 99) as p99 by host.name
| where p99 > 2000 | sort - p99
```
→ host-17: p50=450ms p99=4200ms, host-23: p50=420ms p99=3800ms. Both elevated across all percentiles.

**Step 3 — pivot (Theta AnotB)**: "New error signatures post-deploy?"
```sql
source=investigation-sketches-* | where service_name="checkout-service"
| eval pre=sketch_merge(error_code_hll) FILTER(window_end<"2025-01-15T10:00:00Z")
| eval post=sketch_merge(error_code_hll) FILTER(window_start>="2025-01-15T10:00:00Z")
| eval new_errors=sketch_diff(post, pre) | eval count=sketch_estimate(new_errors)
```
→ `count: 3` — three new error signatures since deploy.

**Step 4 — compare (Theta intersection)**: "Are slow users = error users?"
```sql
source=investigation-sketches-* | where service_name="checkout-service" AND window_start>="2025-01-15T10:00:00Z"
| eval slow=sketch_merge(user_id_theta) FILTER(p99>2000)
| eval errs=sketch_merge(user_id_theta) FILTER(has_new_errors=true)
| stats sketch_estimate(sketch_intersect(slow,errs)) as both, sketch_estimate(slow) as total_slow
```
→ `both: 11,203 | total_slow: 12,847` — 87% overlap. Deploy caused errors → latency. **Rollback.**

## 8. Phased Rollout

| Phase | Sketches | Primitives | Timeline |
|-------|----------|-----------|----------|
| **1** | HLL + KLL | discover + narrow | 8-10 weeks |
| **2** | + Theta | + pivot + compare | 6-8 weeks |
| **3** | + FreqItems + Tuple | + heavy hitters | 6-8 weeks |

Phase 1 follows existing `cardinality`/`percentiles` agg patterns. Phase 2 unlocks set operations — the key differentiator vs any existing OpenSearch aggregation.

## 9. Engineering Effort

| Component | Estimate |
|-----------|----------|
| Data Prepper `sketch_aggregate` AggregateAction | 2-3 weeks |
| OpenSearch `sketch_build` aggregation (HLL/KLL) | 3-4 weeks |
| OpenSearch `sketch_merge` aggregation | 2-3 weeks |
| PPL functions Phase 1 (count_distinct, percentile, merge, estimate) | 2-3 weeks |
| PPL functions Phase 2 (intersect, diff, top_k) | 2-3 weeks |
| MCP tool wrappers | 1 week |
| Integration tests + benchmarks | 2-3 weeks |
| **Phase 1 total** (HLL+KLL end-to-end) | **10-14 weeks** |
| **Phase 1+2 total** (+Theta) | **16-22 weeks** |
| **All phases** | **~24-30 weeks** |
