# DataSketches Integration Patterns Across Analytics Systems

## 1. Apache Druid — Deepest Integration (Reference Architecture)

Druid has the most mature DataSketches integration. Key architecture decisions:

**Dual-mode operation: ingestion-time vs query-time sketches**
- **Ingestion-time** (preferred): Sketches built during data ingestion via `metricsSpec` aggregators (e.g., `HLLSketchBuild`, `thetaSketch`). Raw values are replaced with sketch objects stored in segments. This enables rollup — high-cardinality columns become compact sketch metrics.
- **Query-time**: Sketches built on-the-fly from raw dimension columns. Works but slower — no pre-aggregation benefit.
- **Pre-built ingestion**: External systems (Pig, Hive) can produce Base64-encoded sketches that Druid ingests via `HLLSketchMerge` / `isInputThetaSketch: true`.

**Storage format**: Sketches stored as opaque binary blobs in Druid segments as "additive metrics." The segment format treats them like any other metric column.

**Query model — Aggregators + Post-Aggregators**:
- Aggregators: `thetaSketch`, `HLLSketchBuild`, `HLLSketchMerge`, `quantilesDoublesSketch` — merge sketches across segments/rows.
- Post-aggregators: Extract estimates (`thetaSketchEstimate`, `HLLSketchEstimate`), perform set operations (`thetaSketchSetOp` with UNION/INTERSECT/NOT), compute quantiles/histograms/CDF/rank.
- `shouldFinalize` flag controls whether query returns the estimate (double) or the intermediate sketch (for further composition).

**Sketch types supported**: Theta, HLL, Quantiles (Doubles), KLL, Tuple (ArrayOfDoubles).

**Key design decision**: Separate Build vs Merge aggregator types (HLL). Build creates sketches from raw values; Merge combines existing sketches. This distinction is critical for the ingestion pipeline.

## 2. Apache Spark — Native Built-in Functions (Since 4.x)

Spark integrated DataSketches directly into its SQL engine as built-in aggregate functions:

**HLL sketches**: `hll_sketch_agg(expr, lgConfigK)`, `hll_union_agg(expr)`, `hll_sketch_estimate(expr)`, `hll_union(first, second)`. Full accumulate/merge/estimate lifecycle.

**Theta sketches**: `theta_sketch_agg(expr)`, `theta_union_agg(expr)`, `theta_intersection_agg(expr)`, `theta_sketch_estimate(expr)`, `theta_union()`, `theta_intersection()`, `theta_difference()`. Complete set operations.

**KLL quantiles**: `kll_sketch_agg_float/double/bigint(expr, k)`, `kll_sketch_get_quantile_*()`, `kll_sketch_get_rank_*()`, `kll_sketch_merge_*()`, `kll_sketch_to_string_*()`.

**Approximate top-k**: `approx_top_k()`, `approx_top_k_accumulate()`, `approx_top_k_combine()`, `approx_top_k_estimate()` — three-phase pattern (accumulate → combine → estimate).

**Key pattern**: Sketches are binary column values. The three-phase pattern (build/accumulate → merge/union → estimate/extract) is consistent across all sketch types. Spark uses `datasketches-java` under the hood.

## 3. Google BigQuery — HLL++ Only, SQL Functions

BigQuery uses Google's HLL++ variant (not Apache DataSketches) with four SQL functions:
- `HLL_COUNT.INIT(expr [, precision])` — creates sketch from values
- `HLL_COUNT.MERGE(sketch)` — aggregate merge of sketches
- `HLL_COUNT.MERGE_PARTIAL(sketch)` — partial merge (for re-aggregation)
- `HLL_COUNT.EXTRACT(sketch)` — get cardinality estimate

**Key design decision**: Only HLL (cardinality). No quantiles, no theta/set-operations. Precision is configurable (10-24, default 15). Sketches are opaque BYTES values. The INIT/MERGE/EXTRACT naming convention is clean and SQL-friendly.

## 4. Amazon Redshift — First-Class HLLSKETCH Data Type

Redshift introduced a dedicated `HLLSKETCH` column data type:
- `HLL(expr)` — one-shot approximate distinct count
- `HLL_CREATE_SKETCH(expr)` — creates an HLLSKETCH value (aggregate)
- `HLL_CARDINALITY(sketch)` — extracts estimate from sketch
- `HLL_COMBINE(sketch)` — merges sketches (aggregate)

**Storage**: HLLSKETCH is a first-class data type. Sketches auto-convert between sparse (JSON) and dense (Base64) representations based on size. Fixed precision of 15 (logm).

**Key design decision**: Making sketch a column type (not just a function return) enables storing pre-aggregated sketches in tables for later re-aggregation. Only HLL — no quantiles or theta.

## 5. PostgreSQL Extension — C/C++ Native Extension Pattern

`apache/datasketches-postgresql` wraps `datasketches-cpp` as a PostgreSQL extension:
- Custom data types: `cpc_sketch`, `hll_sketch`, `theta_sketch`, `kll_float_sketch`, `frequent_strings_sketch`
- Aggregate functions: `cpc_sketch_build(value)`, `theta_sketch_build(value)`, etc.
- Merge functions: `cpc_sketch_union(sketch)`, `theta_sketch_union(sketch)` (both aggregate and non-aggregate forms)
- Estimate functions: `cpc_sketch_get_estimate()`, `theta_sketch_get_estimate()`
- Set operations: `theta_sketch_intersection()`, `theta_sketch_a_not_b()`

**Architecture**: C wrapper around `datasketches-cpp` using PostgreSQL's extension API (`CREATE EXTENSION datasketches`). SQL functions defined in `.sql` files, C implementations in `src/`. Uses `PGXN` for distribution.

**Key pattern**: Each sketch type gets its own custom PostgreSQL type + a family of functions following `{type}_{operation}` naming.

## 6. Elasticsearch / OpenSearch — No Official Plugin Exists

**Elasticsearch**: A community member proposed an HLL sketch aggregation plugin in 2020 (discuss.elastic.co). The plugin reads binary doc values, deserializes as HllSketch objects, combines them, and returns estimates. It was never merged into Elasticsearch core. The author reported 150% performance improvement over Druid for their use case. Status: abandoned proof-of-concept.

**OpenSearch**: No DataSketches plugin exists. OpenSearch has a built-in `cardinality` aggregation using HLL++ (similar to Elasticsearch), but it operates only at query time on raw values — no sketch storage, no pre-aggregation, no set operations, no quantile sketches.

**Gap**: This is the opportunity. Neither ES nor OpenSearch supports storing pre-built sketches, merging them across shards, or exposing the full DataSketches family.

## 7. Common Architecture Patterns (Consensus Approach)

| Pattern | Druid | Spark | BigQuery | Redshift | PostgreSQL |
|---|---|---|---|---|---|
| Custom data type for sketches | Binary metric | Binary column | BYTES | HLLSKETCH | Custom types |
| Build from raw values | ✅ | ✅ | ✅ | ✅ | ✅ |
| Merge/union sketches | ✅ | ✅ | ✅ | ✅ | ✅ |
| Extract estimate | ✅ | ✅ | ✅ | ✅ | ✅ |
| Store pre-built sketches | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ingest external sketches | ✅ (Base64) | ✅ | ✅ | ✅ (JSON/Base64) | ✅ |
| Set operations (theta) | ✅ | ✅ | ✗ | ✗ | ✅ |
| Quantile sketches | ✅ | ✅ | ✗ | ✗ | ✅ |
| Ingestion-time rollup | ✅ | N/A | N/A | ✅ | ✅ |

**Universal three-phase lifecycle**: BUILD (raw → sketch) → MERGE (sketch + sketch → sketch) → ESTIMATE (sketch → scalar). Every system implements this.

**Key transferable patterns for OpenSearch**:
1. **Sketch as binary doc_value**: Store serialized sketch bytes in a dedicated field type (like Druid's metric columns)
2. **Shard-level merge**: Each shard builds/merges sketches locally, coordinator merges shard-level sketches (maps to ES aggregation reduce phase)
3. **Build vs Merge distinction**: Separate aggregation paths for raw-value-to-sketch vs sketch-to-sketch (Druid's HLLSketchBuild vs HLLSketchMerge)
4. **Finalization control**: Option to return intermediate sketch (for sub-aggregations) or final estimate
5. **Base64 serialization**: For ingesting pre-built sketches and for API responses
6. **Extension/plugin model**: PostgreSQL's approach of wrapping `datasketches-cpp`/`datasketches-java` is directly applicable to OpenSearch's plugin architecture
