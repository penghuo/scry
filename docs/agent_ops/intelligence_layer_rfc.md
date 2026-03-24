# Engineering Proposal: OpenSearch Intelligence Layer

**Proposal:** We propose adopting an Intelligence Layer as the technical direction for agent-native observability in OpenSearch. The Intelligence Layer continuously maintains knowledge about monitored systems -- topology, baselines, anomalies -- so that agents and humans read pre-computed context instead of re-deriving it per investigation. Without topology, an agent investigating a service alert must discover dependencies through iterative querying -- typically 5-15 exploratory queries before narrowing to the relevant subgraph. With pre-computed topology, the agent starts with the dependency set directly, reducing the typical discovery phase from 10-15 exploratory queries to a single API call. The Intelligence Layer eliminates the most common class of agent query errors and positions OpenSearch as the foundation for agent-native observability.

## Situation

The observability market stores data as flat, disconnected JSON documents. Logs, spans, and metrics arrive as independent streams with no built-in relationships. OpenSearch indexes and retrieves these documents, but it holds no accumulated understanding of the systems those documents describe. Every query -- whether from a human analyst or an AI agent -- starts from scratch: scan raw documents, aggregate, interpret, and discard the result.

## Complication

AI agents make this problem acute. Datadog's Watchdog automatically surfaces anomalies and correlates them with deployments. Elastic's AI Assistant uses pre-indexed service maps and baseline metrics. Competitors treat pre-computed context as table stakes for AI-assisted investigation; OpenSearch provides none.

When an agent investigates "why is checkout-service slow?", it faces a combinatorial search space: all services multiplied by all signal types multiplied by all time windows. The agent does not know which services depend on checkout-service, what normal latency looks like, whether an anomaly is present, or how to correctly query a specific metric (counter vs. gauge, required GROUP BY clauses, field name conventions). Each investigation starts blind, and the agent burns tokens and time re-deriving context that the platform already has the data to provide.

Meanwhile, the same investigation yesterday produced the same intermediate understanding -- service topology, baseline values, anomaly windows -- that was computed and then thrown away. The platform accumulates data but never accumulates knowledge.

## Question

How should OpenSearch evolve to give agents (and humans) instant access to pre-computed understanding of monitored systems, rather than forcing every consumer to reconstruct that understanding from raw data on every query?

## Answer

We propose an Intelligence Layer: a set of continuously-updated knowledge APIs that sit alongside the existing query engine. The Intelligence Layer complements existing OpenSearch features -- ISM, alerting, and the Anomaly Detection plugin -- rather than replacing them. It provides the context that agents need before they compose queries, and the interpretation context they need after they get results.

Derived knowledge is persisted in dedicated OpenSearch system indices, following the same pattern used by the Anomaly Detection plugin for detector state and results. This provides durability, replication, and access control through existing OpenSearch mechanisms.

The Intelligence Layer provides three types of help, mapping to the three phases of every agent investigation:

**Search Space Narrowing** answers "which services are related?" and "which signals are abnormal?" -- reducing the search space from thousands of combinations to a handful of candidates before the agent runs a single query.

**Query Context** provides field metadata (names, types, cardinality estimates, counter-vs-gauge semantics) and baselines so the agent writes correct queries on the first attempt.

**Explanation Context** provides surrounding operational facts -- deployments, error groupings, log patterns -- moving the agent from observation ("error rate spiked at 14:32") to explanation ("connection-refused errors in payment-service correlate with the 14:30 deployment").

Knowledge builds through three mechanisms: automatic maintenance (the primary differentiator -- OpenSearch derives topology from traces, field profiles from indexed documents, and anomaly baselines from the data stream with zero configuration), customer-guided configuration (SLO thresholds, error budgets), and agent-contributed knowledge (agents write back confirmed root causes to enrich future investigations). Agent-contributed knowledge is treated as low-confidence input: it is stored separately, surfaced with provenance metadata, and subject to TTL-based expiration. It does not modify automatically-derived knowledge. Agent-contributed knowledge is strictly additive and does not affect the ranking or filtering of automatically-derived knowledge. Validation and conflict resolution policies are defined in the design document.

The Intelligence Layer consumes anomaly results from the existing AD plugin rather than reimplementing detection. It adds an agent-facing API that aggregates detector results across services, attaches topology context, and returns anomalies ranked by relevance to the current investigation. The AD plugin owns detection; the Intelligence Layer owns presentation and correlation. When the AD plugin is disabled, misconfigured, or has zero active detectors, the Anomaly Detection Integration capability degrades gracefully: the API returns an empty result set with a status indicating no anomaly data is available, rather than failing. Integration strategy details are scoped for the design document.

Every Intelligence Layer response includes a freshness timestamp and confidence score. Topology responses report time-since-last-rebuild; baseline responses report the observation window size. Agents use these signals to decide whether to trust pre-computed context or fall back to direct querying. When confidence falls below a configurable threshold, the Intelligence Layer returns a degraded-mode response that includes the stale data with an explicit warning, rather than silently serving potentially misleading context. Expected topology staleness is bounded by the rebuild interval (5-15 minutes). During incidents where topology changes mid-investigation (cascading failures, failovers), the agent receives stale topology with a low-confidence flag and falls back to targeted dependency discovery queries — partial value (narrowed starting point) rather than full blind search. On-demand topology rebuild triggered by agent request is in scope for the design document.

Topology derivation requires trace data; in environments without tracing, the remaining capabilities still provide value. Derived knowledge has staleness windows during topology changes, cold-start periods on new clusters, and streaming anomaly detection (Random Cut Forest) convergence time -- known constraints addressed in the design phase.

The interface is a REST API returning JSON, separate from the query engine. Intelligence queries have different access patterns and caching semantics than document search, warranting a dedicated surface.

We prioritize five must-have capabilities for the first phase, ordered by implementation risk (lowest first):

1. **Field Profiles** -- semantic type information (counter vs. gauge), cardinality estimation, and field name conventions merged from indexed documents. Field Profiles carry the lowest implementation risk and can ship independently as the first deliverable.
2. **Service Topology** -- dependency graphs derived from trace data.
3. **Temporal Baselines** -- rolling statistical summaries per metric per service.
4. **Anomaly Detection Integration** -- agent-consumable anomaly context aggregated from the existing AD plugin. AD plugin integration is the highest-risk item; we scope it as a separate spike before committing to the integration strategy.
5. **Change Detection** -- correlating deployments and configuration changes with signal shifts. Change Detection depends on an external event source for deployment data (CI/CD webhooks or manual annotation); this dependency is validated during the design phase.

Additional capabilities -- Log Patterns, Error Clustering, Causal Graph, Health Matrix, SLO Burn Rate -- follow in subsequent phases.

## Resource Model

Intelligence Layer state is stored in dedicated system indices (e.g., `.intelligence_topology`, `.intelligence_baselines`). Topology graphs are small (KB per service); field profiles use fixed-size sketches (~1KB per field per index); temporal baselines store rolling windows (~10KB per metric per time granularity). Storage scales with field count: a typical observability cluster with 500-2,000 unique fields per index pattern and 500 index patterns requires low single-digit GB. High-cardinality clusters (10K-50K fields per pattern) scale linearly — at 50K fields the estimate reaches ~25GB, which the design document addresses with field sampling and top-K sketch strategies.

Field profiles and baselines update asynchronously during ingest via lightweight background processors. The <1ms per-document estimate is a target derived from analogous ingest processors (e.g., the AD plugin's feature extraction); the prototype validates this under production-scale throughput. At 100K docs/sec, synchronous per-document overhead is not viable — the design assumes asynchronous batch processing with configurable flush intervals. Topology rebuilds run as periodic background jobs (every 5-15 minutes). Anomaly detection leverages the existing AD plugin's compute model. Total incremental CPU overhead target is <5% of ingest throughput. The Intelligence Layer can be disabled per-cluster or per-capability for clusters where the overhead is unacceptable.

## Security Model

Intelligence Layer APIs enforce the same document-level and field-level access controls (FGAC) as the underlying data. Topology responses are filtered to include only services the caller has read access to in the source trace indices. Field profiles and baselines inherit the index-level permissions of their source indices. In multi-tenant deployments, each tenant's intelligence state is isolated by index pattern. The security model is detailed in the design document, but the principle is: the Intelligence Layer never exposes information that the caller could not obtain by querying the raw data directly.

## Proposal

We propose adopting the Intelligence Layer as a technical direction for OpenSearch. Without it, every agent-based observability product built on OpenSearch hits the same wall: agents that start blind, write wrong queries, and waste tokens re-deriving context the platform already has. The Intelligence Layer removes that wall at the platform level, benefiting every agent built on top.

Phase 1 (design document through prototype validation) requires 2-3 engineers over 8 weeks. Production hardening and subsequent phases are scoped in the design document.

Next steps:

1. Publish a design document covering the five must-have capabilities: Field Profiles, Service Topology, Temporal Baselines, Anomaly Detection Integration, and Change Detection. Target: within 4 weeks.
2. Build a prototype of Field Profiles and Service Topology to validate the approach with a real agent workflow. Target: within 8 weeks.
3. Spike on AD plugin integration strategy to derisk the highest-uncertainty item. Target: within 6 weeks.
4. Identify design partners running agent-based investigation workflows to validate that the three types of help (search space narrowing, query context, explanation context) match real agent needs.
