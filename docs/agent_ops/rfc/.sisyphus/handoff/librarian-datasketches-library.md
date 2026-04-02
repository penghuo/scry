# Apache DataSketches Library — Research for OpenSearch Observability Integration

## Library Overview
Apache DataSketches is a production-quality library of stochastic streaming algorithms (sketches) that process data in a single pass with mathematically proven error bounds. Available in Java, C++, Python, Rust, Go with cross-language binary compatibility. Latest Java versions: v6.2.0 (JDK 8/11), v7.0.1 (JDK 17), v8.0.0 (JDK 21), v9.0.0 (JDK 25+). Maven: `org.apache.datasketches:datasketches-java`.

## Sketch Families Relevant to Observability

### 1. KLL Quantiles Sketch — Latency Percentiles (P50/P95/P99/P99.9)
- **Use case**: Latency distributions, SLO monitoring, histogram generation, PMF/CDF computation
- **Java classes**: `KllDoublesSketch`, `KllFloatsSketch`, `KllLongsSketch`, `KllItemsSketch` (package: `org.apache.datasketches.kll`)
- **Accuracy**: Additive rank error ~1.65% at default K=200 (99% confidence). Error is constant across all ranks. Configurable via K (not restricted to powers of 2).
- **Memory**: Near-optimal size for given accuracy. Significantly smaller than classic quantiles sketch at equivalent error. Serialized via `toByteArray()` (always compact/immutable).
- **Mergeability**: ✅ Direct `merge()` method (no separate Union object needed). Works with on-heap, off-heap, and Memory-wrapped compact byte arrays.
- **Off-heap**: ✅ `newDirectInstance()` for float/double/long variants
- **Key API**: `update(value)`, `getQuantile(rank)`, `getRank(value)`, `getCDF()`, `getPMF()`, `merge()`, `toByteArray()`, `heapify(Memory)`
- **Recommendation**: **Primary choice for latency percentiles.** Best accuracy-per-byte ratio among quantile sketches.

### 2. REQ Sketch — Extreme Tail Latencies (P99.99, P99.999)
- **Use case**: When extreme tail accuracy matters more than median accuracy (e.g., P99.999 SLO)
- **Java class**: `ReqFloatsSketch` (package: `org.apache.datasketches.req`)
- **Accuracy**: Relative error — accuracy improves at the chosen end of rank domain (HRA or LRA mode). Ideal for 99.999%ile.
- **Mergeability**: ❌ No union support in features matrix
- **Recommendation**: Niche use. KLL is better for general observability; REQ only if extreme-tail SLOs are critical.

### 3. HyperLogLog (HLL) Sketch — Cardinality Estimation
- **Use case**: Count distinct users, IPs, trace IDs, unique error signatures
- **Java class**: `HllSketch` (package: `org.apache.datasketches.hll`)
- **Accuracy**: RSE = 0.8326/√K. At lgK=12 (K=4096): ~1.3% RSE at 95.4% confidence. ~20% more accurate than standard HLL due to HIP estimator.
- **Memory**: Three compression levels — HLL_4 (most compact, 16x smaller than Theta), HLL_6, HLL_8 (fastest). At lgK=12: ~2.5KB (HLL_4) to ~5KB (HLL_8) serialized.
- **Mergeability**: ✅ Union operator. No intersection/difference (use Theta for set ops).
- **Off-heap**: ✅
- **Key API**: `new HllSketch(lgK, TgtHllType)`, `update()`, `getEstimate()`, `getUpperBound(numStdDev)`, `getLowerBound(numStdDev)`, `toCompactByteArray()`, `HllSketch.heapify(byte[])`
- **Recommendation**: **Primary choice for cardinality.** Best size-to-accuracy ratio for pure count-distinct. Use CPC sketch if even smaller size needed (30-40% smaller than HLL).

### 4. Theta Sketch — Set Operations on Cardinalities
- **Use case**: Compute union/intersection/difference of distinct-count sets. E.g., "users who hit service A AND service B", funnel analysis, overlap detection.
- **Java class**: `Sketch` (package: `org.apache.datasketches.theta`)
- **Accuracy**: RSE = 1/√K. At K=4096: ~1.56% RSE.
- **Memory**: Larger than HLL (2-16x) but supports full set algebra. Updatable size: 8 bytes per entry + overhead.
- **Mergeability**: ✅ Full set operations — Union, Intersection, AnotB (Difference), Jaccard similarity
- **Off-heap**: ✅ Compact and updatable forms. Concurrent variant for multi-threaded environments.
- **Key API**: `UpdateSketch.builder().setNominalEntries(k).build()`, `update()`, `compact()`, `toByteArray()`, `Sketches.heapifySketch(Memory)`, `SetOperation.builder().buildUnion/Intersection/AnotB()`
- **Recommendation**: **Essential for set-expression queries.** Use when you need intersection/difference, not just union. Pair with HLL for pure cardinality.

### 5. Tuple Sketch — Associative Set Operations
- **Use case**: Cardinality + associated metrics. E.g., distinct users with their total latency, click counts per unique visitor.
- **Java class**: `Sketch<S>` (package: `org.apache.datasketches.tuple`)
- **Mergeability**: ✅ Union, Intersection, Difference
- **Recommendation**: Useful for advanced observability combining cardinality with aggregated metrics.

### 6. Frequent Items Sketch — Heavy Hitters / Top-K
- **Use case**: Find most frequent error codes, top endpoints, heaviest API callers, noisy-neighbor detection
- **Java classes**: `ItemsSketch<T>`, `LongsSketch` (package: `org.apache.datasketches.frequencies`)
- **Accuracy**: Deterministic bounds: (UB - LB) ≤ W × 3.5/M where W=total count, M=maxMapSize. Exact if fewer than 0.75×maxMapSize distinct items.
- **Memory**: Internal: 18 × mapSize bytes. Max: 18 × maxMapSize bytes. mapSize must be power of 2.
- **Mergeability**: ✅ `merge()` with another sketch
- **Error types**: NO_FALSE_POSITIVES (conservative) or NO_FALSE_NEGATIVES (inclusive) at query time
- **Key API**: `new ItemsSketch<>(maxMapSize)`, `update(item, count)`, `getFrequentItems(ErrorType)`, `getEstimate(item)`, `getUpperBound(item)`, `getLowerBound(item)`, `merge()`, `toByteArray()`, `ItemsSketch.getInstance(Memory, ArrayOfItemsSerDe)`
- **Recommendation**: **Primary choice for anomaly/top-K detection.** Excellent for identifying noisy neighbors and dominant error patterns.

## Serialization & Cross-Language Compatibility
- All sketches serialize to compact `byte[]` via `toByteArray()` / `toCompactByteArray()`
- Deserialize via static `heapify(Memory)` or `getInstance(Memory)` methods
- Binary format is cross-language compatible (Java ↔ C++ ↔ Python ↔ Rust)
- The `datasketches-memory` component provides `Memory` and `WritableMemory` abstractions for zero-copy off-heap access
- Compact serialized form is immutable/read-only; updatable form is larger

## Mergeability Summary (Critical for Distributed Aggregation)

| Sketch | Union | Intersection | Difference | Merge Method |
|--------|-------|-------------|------------|--------------|
| KLL | ✅ | — | — | `sketch.merge(other)` |
| HLL | ✅ | — | — | `Union.update(sketch)` |
| Theta | ✅ | ✅ | ✅ | `SetOperation` builders |
| Tuple | ✅ | ✅ | ✅ | `SetOperation` builders |
| FreqItems | ✅ | — | — | `sketch.merge(other)` |
| REQ | ❌ | — | — | — |

All mergeable sketches support multi-level aggregation (shard→node→cluster) with bounded error growth.

## Memory vs Accuracy Quick Reference

| Sketch | Default K | Typical Error | Serialized Size (default) |
|--------|-----------|---------------|--------------------------|
| KLL (doubles) | 200 | ~1.65% rank error | ~3-4 KB |
| HLL_4 | lgK=12 | ~1.3% RSE | ~2.5 KB |
| HLL_8 | lgK=12 | ~1.3% RSE | ~5 KB |
| Theta | 4096 | ~1.56% RSE | ~32 KB |
| FreqItems | 2048 | W×0.0017 | ~36 KB |

## OpenSearch Integration Considerations
1. **Storage**: Sketches serialize to byte arrays → store as OpenSearch `binary` field type
2. **Aggregation**: All recommended sketches are mergeable → natural fit for OpenSearch's shard-then-reduce aggregation model
3. **Java native**: All sketches are pure Java with no native dependencies. Maven coordinates: `org.apache.datasketches:datasketches-java:VERSION`
4. **Memory component**: `org.apache.datasketches:datasketches-memory` for off-heap operation (useful for large aggregations)
5. **Existing integrations**: Already integrated into Druid, Hive, Pig, Pinot, BigQuery, PostgreSQL — proven at scale
6. **Thread safety**: Theta sketch has a dedicated concurrent variant for multi-threaded update scenarios

## Sources
- https://datasketches.apache.org/ (main site)
- https://datasketches.apache.org/docs/Architecture/MajorSketchFamilies.html
- https://datasketches.apache.org/docs/Architecture/SketchFeaturesMatrix.html
- https://datasketches.apache.org/docs/KLL/KLLSketch.html
- https://datasketches.apache.org/docs/HLL/HllSketches.html
- https://datasketches.apache.org/docs/Theta/ThetaSketches.html
- https://datasketches.apache.org/docs/Frequency/FrequentItemsOverview.html
- https://datasketches.apache.org/docs/QuantilesAll/QuantilesOverview.html
- https://datasketches.apache.org/docs/Background/SketchOrigins.html
