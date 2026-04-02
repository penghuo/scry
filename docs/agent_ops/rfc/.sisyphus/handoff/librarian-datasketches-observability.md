# DataSketches for Observability Investigation Workflows

## Sources

| URL | Type | Relevance |
|-----|------|-----------|
| https://datasketches.apache.org/docs/Background/TheChallenge.html | official | high |
| https://datasketches.apache.org/docs/Theta/ThetaSketchSetOps.html | official | high |
| https://datasketches.apache.org/docs/KLL/KLLAccuracyAndSize.html | official | high |
| https://datasketches.apache.org/docs/HLL/HllSketches.html | official | high |
| https://datasketches.apache.org/docs/Frequency/FrequencySketches.html | official | high |
| https://docs.databricks.com/aws/en/sql/language-manual/functions/theta_difference | official | medium |
| https://arxiv.org/abs/2509.11633 (ADAPTIVE-GRAPHSKETCH) | research | medium |

## Sketch → Investigation Primitive Mapping

| RFC Primitive | Sketch Family | Operation | What It Answers |
|---------------|--------------|-----------|-----------------|
| **discover** | HLL / CPC | `getEstimate()` | "How many unique users/IPs/error-codes exist in this window?" |
| **narrow** | KLL | `getQuantile(rank)` | "What's the p95 latency? Which requests are above the 99th percentile?" |
| **pivot** | Theta | `AnotB(sketch_A, sketch_B)` | "Which user-IDs appeared in window B but not window A?" (new arrivals / departures) |
| **compare** | Theta | `intersection()` + `AnotB()` | "What changed between baseline and incident?" (set difference = delta) |
| **aggregate** | All families | `union()` / `merge()` | "Roll up per-node sketches into per-service, per-cluster views" |

## KLL Sketches → Latency Percentiles (narrow)

KLL sketches compute approximate quantiles (p50/p95/p99) in a single pass without storing raw values. Key properties for investigation:

- **Fixed rank error**: K=200 (default) gives ±1.33% rank error. For p99 latency, the true quantile lies between `getQuantile(0.9767)` and `getQuantile(0.9933)`. Sufficient for SLO investigation.
- **Sub-linear size**: A KLL float sketch over 1 billion items is ~1 KB (K=200). Storing raw values would require ~4 GB. That's a **4,000,000x** reduction.
- **Mergeable**: Per-host KLL sketches merge into per-service sketches. `union.update(hostSketch)` across 1000 hosts produces a single service-level latency distribution in milliseconds.
- **Histogram generation**: `getQuantiles(splitPoints)` returns the full CDF, enabling "show me the latency distribution for this endpoint during the incident window" without scanning raw data.

**Investigation scenario**: "p99 latency spiked from 200ms to 2s. Which hosts are contributing?"
→ Query per-host KLL sketches, call `getQuantile(0.99)` on each. Hosts with p99 > threshold are the culprits. Cost: read ~1 KB per host vs scanning billions of log lines.

## HLL Sketches → Cardinality Estimation (discover)

HLL estimates count-distinct with ~1.3% RSE at lgK=14 (16 KB). CPC is 30-40% smaller for same accuracy.

- **Blast radius**: "How many unique users hit this error?" → `hllSketch.getEstimate()` returns ~1M ± 13K. No need to `SELECT COUNT(DISTINCT user_id)` over terabytes.
- **Confidence bounds**: `getUpperBound(2)` / `getLowerBound(2)` give 95.4% confidence interval, critical for incident severity assessment.
- **Speed**: HLL update is ~10-20 ns per item. Pre-computed sketches answer cardinality queries in microseconds vs minutes for exact COUNT DISTINCT.

**Investigation scenario**: "Is this a widespread outage or isolated?"
→ Compare `hll_affected_users.getEstimate()` against `hll_total_users.getEstimate()`. If ratio > 0.5, it's widespread. Answer in microseconds.

## Theta Set Operations → Change Detection (pivot, compare)

Theta sketches uniquely support set intersection, union, and **difference** (AnotB) while maintaining cardinality estimates. This is the key differentiator for investigation workflows.

- **AnotB (set difference)**: `aNotB(sketch_now, sketch_baseline)` returns a sketch of items present now but absent from baseline. The estimate of this result sketch = count of *new* items.
- **Composable expressions**: `((A ∪ B) ∩ (C ∪ D)) \ (E ∪ F)` — full set algebra on sketches. Enables complex investigation queries like "users who hit both service A and B errors, excluding known bot IPs."
- **Databricks native**: `theta_difference(sketch_a, sketch_b)` is a built-in SQL function, confirming production adoption for this pattern.

**Investigation scenario**: "After the deploy, which new error signatures appeared?"
→ `theta_AnotB(sketch_post_deploy, sketch_pre_deploy).getEstimate()` = count of new distinct error signatures. The result is itself a sketch that can be further intersected with other dimensions.

**Change detection pattern**:
```
baseline_sketch = theta_sketch(user_ids, window=[-2h, -1h])
current_sketch  = theta_sketch(user_ids, window=[-1h, now])
new_users       = AnotB(current_sketch, baseline_sketch)  // appeared
lost_users      = AnotB(baseline_sketch, current_sketch)  // disappeared
```
A spike in `lost_users.getEstimate()` signals user drop-off — an anomaly.

## Frequent Items → Heavy Hitters (discover, narrow)

The Frequent Items sketch identifies items whose frequency exceeds a threshold, using sub-linear space. It is an "aggregating" sketch: duplicate items accumulate weights.

- **Top error codes**: Feed error codes into `ItemsSketch<String>`, query `getFrequentItems(ErrorType.NO_FALSE_NEGATIVES)` to get guaranteed heavy hitters.
- **Top slow endpoints**: Use weighted updates where weight = latency. `sketch.update(endpoint, latencyMs)` surfaces endpoints contributing most to total latency budget.
- **Mergeable**: Per-partition frequent items sketches merge, preserving the heavy-hitter guarantee across distributed systems.

**Investigation scenario**: "What's causing the error rate spike?"
→ Frequent Items sketch over error codes in the incident window. Top-3 items with `getEstimate()` > N/10 are the dominant error codes. No GROUP BY + ORDER BY + LIMIT over billions of rows.

## Mergeability → Hierarchical Aggregation (aggregate)

All DataSketches families support merge/union. This is the architectural enabler for observability at scale:

```
Level 0: per-process sketches  (created at edge, ~1 KB each)
Level 1: per-host sketches     (merge 10-50 process sketches)
Level 2: per-service sketches  (merge 100-1000 host sketches)
Level 3: per-cluster sketches  (merge 10-100 service sketches)
```

- **Merge speed**: Theta sketches merge at 10-20 million sketches/second in production (per Apache DataSketches docs).
- **Pre-aggregation**: Sketches stored alongside additive metrics in a data-mart. At query time, select rows and merge — no raw data scan.
- **Late data**: Sketches correctly absorb late-arriving data via `union.update()`. Critical for mobile/edge telemetry.
- **Real-time**: Yahoo/Flurry processes streaming data into 1-minute sketch buckets, queried on 15-second intervals. This is not feasible without sketches.

## Speedup Analysis: Sketches vs Exact Computation

| Operation | Exact | Sketch | Speedup |
|-----------|-------|--------|---------|
| Count distinct (1B items) | Sort + dedup: O(N log N), ~4 GB RAM | HLL: O(N) single-pass, 16 KB | **250,000x** memory, ~10x CPU |
| p99 latency (1B items) | Sort all values: O(N log N), ~4 GB | KLL: O(N) single-pass, ~1 KB | **4,000,000x** memory |
| Top-K error codes (1B items) | HashMap + sort: O(N), unbounded memory | FreqItems: O(N), ~10 KB | **100,000x** memory |
| Set difference (two 1B-item sets) | Two sorted sets + merge: ~8 GB | Theta AnotB: two ~8 KB sketches | **500,000x** memory |
| Hierarchical rollup (1000 nodes) | Ship raw data, re-aggregate | Merge 1000 sketches (~1 MB total) | **10-100x** wall-clock, **1000x** network |

The 10-100x wall-clock speedup comes from eliminating raw data scans at query time. Pre-computed sketches turn O(N) queries into O(K) merges where K << N.

## Key Insight for the RFC

Sketches are not just "faster analytics." They are **investigation primitives** — each sketch family maps to a specific cognitive operation an investigator performs:

1. **discover**: "How big is this?" → HLL cardinality
2. **narrow**: "Where exactly?" → KLL percentile thresholds
3. **pivot**: "What's different?" → Theta set difference
4. **compare**: "Before vs after?" → Theta intersection + difference
5. **aggregate**: "Roll it up" → Universal sketch mergeability

The combination enables an investigation loop: discover (HLL: "50K users affected") → narrow (KLL: "p99 latency > 2s on 3 hosts") → pivot (Theta: "200 new error signatures post-deploy") → compare (Theta: "these errors absent from baseline") — all in sub-second query time over data that would take minutes to scan exactly.
