# OpenSearch Architecture: DataSketches Extension Points

## 1. OpenSearch Aggregation Plugin Architecture

### Core Abstractions (from source: `server/src/main/java/org/opensearch/search/aggregations/`)

- **AggregationBuilder**: Defines aggregation parameters, serialization, and creates the `AggregatorFactory`. Each agg type (e.g., `CardinalityAggregationBuilder`) extends this.
- **Aggregator**: Per-shard execution. Collects doc values during the query phase. Produces an `InternalAggregation`.
- **InternalAggregation**: Serializable partial result from one shard. Key method: `reduce(List<InternalAggregation>, ReduceContext)` — merges shard-level results on the coordinating node. This is the map-reduce pattern that makes sketches natural.
- **AggregatorFactory**: Created by the builder; instantiates `Aggregator` per search context.

### Three Aggregation Categories
1. **Metric** (avg, cardinality, percentiles) — produce numeric results, no sub-aggs
2. **Bucket** (terms, histogram, date_histogram) — partition docs into groups, support sub-aggs
3. **Pipeline** (moving_avg, derivative) — operate on outputs of other aggregations

### How Cardinality Already Uses HLL
The existing `cardinality` aggregation uses HyperLogLog++ internally — proving the pattern works. It stores HLL sketches per shard, then merges via `InternalCardinality.reduce()`.

### Adding a New Aggregation Type via Plugin SPI
A plugin registers new aggregations by implementing `SearchPlugin.getAggregations()`:
```java
public class SketchPlugin extends Plugin implements SearchPlugin {
    @Override
    public List<AggregationSpec> getAggregations() {
        return List.of(new AggregationSpec(
            SketchAggregationBuilder.NAME,
            SketchAggregationBuilder::new,  // stream constructor
            SketchAggregationBuilder::parse  // parser
        ));
    }
}
```
The `AggregationSpec` wires: name → builder → factory → aggregator → internal aggregation.

Plugin compatibility is declared in `plugin-descriptor.properties` with `opensearch.version` or `dependencies` range syntax.

## 2. Data Prepper Processor Architecture

### Pipeline Model
```yaml
source → buffer → processor(s) → sink(s)
```
- **Source**: Ingests events (HTTP, Kafka, S3, OTel)
- **Buffer**: Bounded blocking (in-memory) or Kafka-backed. Configurable `buffer_size` and `batch_size`
- **Processor**: Transforms events. Extends `AbstractProcessor` with `execute(Record<Event>)`. Stateless by default.
- **Sink**: Writes to OpenSearch, S3, etc.

### Processor Interface
```java
public abstract class AbstractProcessor<InputRecord, OutputRecord> implements Processor {
    public abstract Collection<Record<OutputRecord>> execute(Collection<Record<InputRecord>> records);
}
```
Metrics: `recordsIn`, `recordsOut`, `timeElapsed` counters/timers.

### Stateful Processors
Stateful processors (aggregate, service-map) retain data across batches. The **Peer Forwarder** routes events to specific nodes by hashing `identification_keys`, ensuring all events for a group land on the same node. Circuit breakers protect heap when stateful processors accumulate too much data.

## 3. Aggregate Processor — Closest Pattern to Sketch Computation

### Configuration
| Option | Description |
|---|---|
| `identification_keys` | Group-by keys (e.g., `["sourceIp", "port"]`) |
| `action` | What to do per group: `count`, `histogram`, `put_all`, `remove_duplicates`, `rate_limiter`, `percent_sampler` |
| `group_duration` | Window duration before auto-conclude (default `180s`) |
| `local_mode` | Skip peer forwarding; aggregate locally per node |

### Action Lifecycle
1. **`handleEvent(event, group)`** — called for each event arriving in a group
2. **`concludeGroup(group)`** — called when `group_duration` expires; emits aggregated event(s)

### Custom Actions
Implement `AggregateAction` interface in Java, register via plugin SPI:
```java
public interface AggregateAction {
    AggregateActionResponse handleEvent(Event event, AggregateActionInput input);
    Optional<AggregateActionOutput> concludeGroup(AggregateActionInput input);
}
```
This is the exact extension point for a `sketch_aggregate` action that maintains DataSketches (HLL, KLL, Theta) per group and emits serialized sketches on conclude.

## 4. Search Pipelines — Query-Time Sketch Operations

### Architecture
Search pipelines intercept queries at the coordinating node:
```
request_processors → OpenSearch query → response_processors
```
Three processor phases:
- **Search request processor**: Modify query before execution
- **Search response processor**: Transform results after execution  
- **Search phase results processor**: Between search phases (e.g., between fetch phases)

### Extension Point for Sketches
A custom **search response processor** could:
1. Intercept aggregation results containing serialized sketch bytes
2. Deserialize and merge sketches from the response
3. Compute final estimates (cardinality, quantiles, set operations)
4. Replace raw sketch bytes with human-readable results

Registration via `SearchPlugin.getSearchPipelineProcessors()`.

## 5. DataSketches Extension Points Summary

### Ingestion Time (Data Prepper)
| Extension Point | Mechanism | Use Case |
|---|---|---|
| **Custom AggregateAction** | Implement `AggregateAction` interface | Maintain sketches per group during streaming ingestion; emit serialized sketches to OpenSearch |
| **Custom Processor** | Extend `AbstractProcessor` | Stateless per-event sketch updates (e.g., add values to a pre-existing sketch field) |
| **Ingest Pipeline Processor** | OpenSearch ingest processor plugin | At index time, initialize sketch binary fields from raw values |

### Query Time (OpenSearch)
| Extension Point | Mechanism | Use Case |
|---|---|---|
| **Custom Aggregation** | `SearchPlugin.getAggregations()` SPI | New `sketch_merge` aggregation: per-shard sketch build → coordinating node reduce via sketch union |
| **Search Response Processor** | `SearchPlugin.getSearchPipelineProcessors()` | Post-process aggregation results to deserialize/merge sketches |
| **Script Aggregation** | `scripted_metric` with init/map/combine/reduce | Prototype sketch operations without a full plugin (slower but no deployment) |

### Key Architectural Insight
The OpenSearch aggregation reduce pattern (`InternalAggregation.reduce()`) and the Data Prepper aggregate processor (`handleEvent`/`concludeGroup`) both mirror the sketch merge paradigm: build partial sketches independently, then union them. This makes DataSketches a natural fit at both layers.

## Sources
- https://docs.opensearch.org/latest/aggregations/
- https://docs.opensearch.org/latest/install-and-configure/plugins/
- https://docs.opensearch.org/latest/search-plugins/search-pipelines/index/
- https://docs.opensearch.org/latest/data-prepper/pipelines/configuration/processors/aggregate/
- https://docs.opensearch.org/latest/data-prepper/managing-data-prepper/configuring-data-prepper/
- https://github.com/opensearch-project/OpenSearch/tree/main/server/src/main/java/org/opensearch/search/aggregations
- https://github.com/opensearch-project/data-prepper/tree/main/data-prepper-plugins
