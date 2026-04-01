下面是英文版 RFC 草稿。

---

# RFC: OpenSearch Agent Observability Investigation Framework

## Status

Draft

## Abstract

Modern observability systems already provide logs, metrics, traces, query, aggregation, visualization, and alerting. However, these capabilities are still primarily organized around interactive entry points such as dashboards, search/query, trace/log/metric exploration, and incident investigation. OpenSearch already has the core building blocks as well: logs, traces, metrics, PPL, Data Prepper, Trace Analytics, Event Analytics, and MCP / agentic AI integration. The issue is not the absence of point capabilities. The issue is that these capabilities have not yet been organized into a reusable, transferable, and auditable investigation process.

This RFC proposes an investigation-first system structure on top of the existing OpenSearch observability stack. It introduces four core constructs: signal catalog, investigation summaries, investigation context / evidence state, and explicit evidence / conclusion / action boundaries. The goal is not to redefine telemetry standards or build a separate platform, but to systematize the investigation path while supporting both human-driven and agent-driven investigation. OpenTelemetry already provides unified semantic conventions for traces, metrics, logs, and resources, and is also evolving semantic conventions for AI agent observability. This RFC builds an OpenSearch-specific investigation organization layer on top of that foundation.

---

## 1. Problem Statement

Existing observability systems already provide strong data collection, query, aggregation, visualization, and alerting capabilities. However, their primary organization model is still centered around interactive entry points such as dashboards, search/query, trace/log/metric exploration, and incident investigation. This model is effective for human analysis, but it fundamentally behaves as a set of analysis tools rather than a system that explicitly models investigation itself as a reusable and extensible capability. Mainstream vendors describe observability platforms in largely the same way, organizing capabilities around monitoring, logging, tracing, APM, and incident response.

Humans and agents generally follow similar strategies when investigating incidents: observe the broad anomaly, narrow the scope, compare candidate causes, gather evidence, and then decide whether to act. The problem is not that agents use a completely different method. The problem is that most of this investigative process still has to be manually stitched together across multiple tools, data sources, and signals. This fragmentation is not an edge case. Grafana’s 2025 survey reports that teams use an average of 8 observability technologies, and Grafana users configure an average of 16 data sources. New Relic’s 2024 report shows that 88% of respondents use two or more monitoring tools, and 34% identify too many tools and data silos as a major obstacle to full-stack observability.

This organization model creates several direct problems. First, the investigation process depends heavily on human expertise and ad hoc interaction, which makes it difficult to reuse and hard to scale reliably in more complex environments. Second, data volume, cost, and noise have already made repeated broad retrieval a real constraint, not just an implementation detail. Grafana’s 2025 survey reports that observability spend accounts for an average of 17% of total compute infrastructure spend, while 10% is the most common response. Grafana’s follow-up cost management article also states that 74% of respondents consider cost a major factor when selecting observability tools. Datadog, in describing Bits AI SRE, also notes that modern production environments are more dynamic and complex, incidents span more services, signals are noisier, and telemetry volumes are larger, making it harder for engineers to quickly identify root cause.

Third, current result shapes are optimized for human reading, not for continuous machine reasoning. Traditional systems mostly output raw hits, charts, aggregate results, and query pages. These are useful for engineers, but that does not mean the system clearly represents the intermediate state of an investigation. LangChain and LangSmith define agent observability around traces that capture execution steps, including tool calls, model interactions, and decision points. Datadog similarly describes Bits AI SRE as an investigation process that iteratively forms hypotheses, gathers relevant telemetry, and continuously updates its reasoning based on evidence.

Fourth, conclusion boundaries, process auditability, and cross-system consistency remain unclear. Datadog explicitly states that Bits AI SRE either produces a clear, evidence-backed conclusion or marks the investigation as inconclusive when data is insufficient. OpenTelemetry, in elevating AI agent observability as a distinct topic in 2025, also explicitly points to fragmentation and semantic inconsistency as real problems, with growing demand for unified observability semantics as AI agents enter enterprise environments.

Therefore, the core problem addressed by this RFC is not that humans and agents use different investigative strategies. The core problem is: **current observability systems primarily expose capabilities for interactive analysis, but lack explicit, structured, and reusable system support for the investigation process itself; and tool fragmentation, data scale, cost pressure, noise, and auditability requirements make this gap increasingly visible in complex environments and even more pronounced in agent scenarios.**

---

## 2. Problem Breakdown: What System Capabilities Are Missing From the Investigation Process

The previous section described the overall problem. This section breaks it down into more concrete capability gaps. The point here is not that existing observability systems lack query, alerting, visualization, or analysis features. The point is that **these capabilities have not been organized into a reusable, transferable, and auditable investigation process.**

### 2.1 Lack of System Support for Investigation Entry, Object Identification, and Context Convergence

An investigation rarely starts from zero information. It usually begins with an entry point: an alert, a deployment, a spike in service errors, a user report, or an anomalous trace. Today, however, turning that entry point into an actionable investigation context still depends heavily on the user. Engineers must decide which signal to inspect first, which time window to isolate, which service, tenant, or version to focus on, and what to examine next.

There is a more fundamental problem underneath this: neither humans nor agents naturally know where metrics, logs, and traces live, nor do they naturally know what data belongs together or how signals correlate. They depend on the system to make investigation objects, data types, relationships, and entry context explicit in advance. Without those structures, the investigation begins with guesswork: where should I look first, what should I inspect first, and are these datasets even related?

Therefore, the gap here is not just the absence of a single entry point. The gap is the absence of a system capability that can quickly locate the relevant object, identify relevant data, and converge on an actionable investigation context.

### 2.2 Lack of System Support for Cross-Signal Narrowing and Candidate Prioritization

The core of investigation is not looking at more data. It is narrowing the scope faster. Real investigations move across metrics, logs, traces, deployments, service dependencies, and other signals to determine which system, dimension, or time window is most likely involved.

Another key action here is comparing and ranking candidate causes. For example: is a recent deployment more suspicious, or is a downstream service more suspicious? Is the issue isolated to one tenant, or is it a global regression? Is the error path more worth following, or the latency path? Today, this narrowing and prioritization process is still mostly performed by engineers manually comparing pages, aggregate views, and time windows.

Therefore, the gap here is not a lack of single-query capability. The gap is the lack of system support for continuously narrowing the search space across multiple signals and dynamically determining what is most worth investigating next.

### 2.3 Lack of Expressiveness for Investigation State, Evidence, and Conclusion Boundaries

Most observability systems are good at storing raw telemetry and final query results. They are not good at expressing the state of the investigation process itself: what has already been checked, what hypotheses were formed, what was ruled out, where the current evidence chain stands, and what the most reasonable next step is.

More importantly, systems usually do not clearly express the boundary of the current conclusion. An investigation does not always lead to a complete and certain root cause. In many cases, the more accurate state is: the current evidence supports a few directions but is not sufficient to confirm them; or most hypotheses have been ruled out, but a key piece of evidence is still missing. Today, systems can show “what data exists,” but they often cannot clearly express “what level of conclusion this data actually supports.”

Therefore, the gap is not only a lack of process recording. It is also a lack of a unified way to represent intermediate evidence, investigation state, uncertainty, and conclusion boundaries.

### 2.4 Lack of Consistent Cross-System Process Semantics

As investigations increasingly depend on multiple systems, tools, and data types, another issue becomes more visible: different systems do not model concepts such as task, step, tool call, memory, artifact, and action in the same way. Even if each system captures part of the process internally, those process fragments become difficult to transfer, combine, and audit once they must move across systems.

This means investigation is not only a query problem. It is also a cross-system representation problem. If different systems model process objects differently, the investigation path becomes difficult to understand consistently, difficult to reuse, and difficult to automate.

---

## 3. Module Matrix: Where the Problems Land Across System Layers

| Problem                                                             | Ingestion | Storage | Query / Execution | Agent Integration | Governance |
| ------------------------------------------------------------------- | --------: | ------: | ----------------: | ----------------: | ---------: |
| Investigation entry, object identification, and context convergence |      High |    High |            Medium |            Medium |        Low |
| Cross-signal narrowing and candidate prioritization                 |    Medium |  Medium |              High |              High |        Low |
| Investigation state, evidence, and conclusion boundary expression   |       Low |    High |            Medium |              High |       High |
| Consistent cross-system process semantics                           |       Low |  Medium |               Low |              High |       High |

This distribution shows three things. First, the problem is not evenly distributed across all layers. Second, Ingestion and Storage determine whether investigation has stable inputs and reusable state. Third, Query / Execution, Agent Integration, and Governance determine whether investigation can continue, whether it can be consumed programmatically, and whether its results can be used reliably. This mapping is also consistent with the current OpenSearch capability boundary: OpenSearch already provides observability ingestion, Data Prepper pipelines, trace analytics, event analytics, and agentic AI / MCP integration, but these capabilities are still organized primarily by functional entry points rather than by investigation process.

---

## 4. Current State

OpenSearch already has the key observability building blocks: OTel-based trace ingestion, Data Prepper pipelines, Trace Analytics, Event Analytics, Metrics Analytics, PPL, support for deriving metrics and histograms from traces, and MCP / agentic AI integration. Trace Analytics explicitly depends on Data Prepper’s entry, raw-trace, and service-map pipelines. OpenSearch observability documentation also already places logs, traces, metrics, event analytics, and notebooks in the same product domain.

Therefore, the OpenSearch gap is not “missing an observability platform” or “missing an agent integration entry point.” The gap is more precisely this: **the existing capabilities have not yet been organized into an investigation-first system structure.** OpenTelemetry already provides resource semantics, service identity, deployment environment semantics, baggage, and other foundational standards. This means OpenSearch does not need to redefine telemetry fundamentals. What it needs to add is an investigation organization layer, a state layer, and a boundary layer.

---

## 5. Design Principles

### 5.1 Center the design on the investigation path

Prioritize capabilities that improve the investigation path, not isolated feature enhancement.

### 5.2 Prioritize shared capabilities for humans and agents

First close the gaps in object identification, cross-signal narrowing, state expression, and boundary expression that both humans and agents need. Then add agent-specific consumption patterns.

### 5.3 Make process explicit, not just results

The system must represent checked scope, candidate sets, evidence sets, conclusion state, and next step, not only raw hits or final charts.

### 5.4 Prioritize programmatic consumption

UI remains important, but core investigation objects and states must not live only in page interactions.

### 5.5 Make evidence, conclusion, and action boundaries explicit

The system must distinguish between leads, evidence, supported conclusions, and which conclusions are eligible for follow-on action.

### 5.6 Evolve incrementally on top of existing OpenSearch and OTel capabilities

Do not redefine OTel fundamentals. Reuse Data Prepper, Trace Analytics, PPL, MCP, and related capabilities. Add an investigation organization layer above them.

---

## 6. Proposed Solution

### 6.1 Ingestion

#### Goal

The goal of the Ingestion layer is not to redefine the telemetry schema. It is to turn incoming OpenSearch data into **investigation-ready input**.

#### Reuse

This RFC directly reuses existing OTel semantics. It does not add mirror fields for `service`, `environment`, `trace_id`, `span_id`, and similar primitives. Service, instance, environment, version, and related foundational identity continue to use OTel resource / semantic conventions.

#### OpenSearch additions

**1. Signal catalog / discovery metadata**
OpenSearch maintains signal discovery metadata during ingestion. This metadata answers the most basic questions: what signals exist for the current object, which index or data source contains logs / traces / metrics, what time range is covered, and which signals can be correlated by service or trace. This does not replace raw data. It prevents both humans and agents from having to guess where to look. Since the current OpenSearch data path is already Collector → Data Prepper → OpenSearch, this metadata can be constructed in the pipeline rather than inferred ad hoc at query time.

**2. Ingest-time investigation summaries**
Ingestion produces summaries for early narrowing instead of forcing all narrowing into the query stage. Phase 1 supports only two types: derived metrics / histograms and mergeable sketches. OpenSearch Data Prepper already supports deriving metrics and histograms from traces. DataSketches are valuable here because they provide mergeable summaries suitable for layered aggregation and fast narrowing.

**3. Optional entry context enrichment**
`investigation entry context` is attached only when the entry is known, such as an alert-triggered workflow, incident replay, or agent run. It is not fabricated for ordinary continuously collected telemetry. OTel baggage and environment variable carriers can both transport this context.

#### Non-goals

This section does not redefine OTel base fields, does not persist investigation process state, and does not perform suspect ranking or conclusion judgment at ingestion time.

---

### 6.2 Storage

#### Goal

The Storage layer persists the investigation structures produced by ingestion as readable, reusable, and incrementally updatable system objects.

#### Proposed storage objects

**1. Signal catalog**
The Storage layer persists the signal catalog. Each catalog record includes at least: object key, signal type, source locator, time coverage, correlation keys, resolution, and freshness. It answers “what signals exist for this object, and where should they be read from,” preventing every investigation from rediscovering data location and correlation conditions.

**2. Investigation summaries**
The Storage layer persists investigation summary objects. Phase 1 stores only two kinds: derived metrics / histograms and mergeable sketches. Each summary record includes at least: object key, time window, source signal, summary type, payload, provenance, and freshness. These are not generic rollups. They are summary objects for early investigation narrowing.

**3. Investigation context**
The Storage layer persists investigation context, including entry conditions, time range, focus objects, checked scope, and current suspect set. This prevents investigation from existing only in a user’s head or page state.

**4. Evidence set and conclusion state**
The Storage layer persists intermediate evidence and conclusion state. Phase 1 supports at least five states: `open`, `narrowed`, `suspected`, `inconclusive`, and `concluded`. Every conclusion may be associated with an evidence set. Datadog explicitly treats `inconclusive` as a legitimate result, which means “unable to conclude” must become a first-class system state rather than an implicit page outcome.

#### Non-goals

The Storage layer does not define suspect ranking algorithms and does not directly emit decisions.

---

### 6.3 Query / Execution

#### Goal

Move the system from “executing isolated queries” to “supporting ongoing investigation.”

#### Proposed execution primitives

**1. discover**
Uses the signal catalog to find what signals are available for the current object, what time coverage they have, and how they can be correlated. This solves “where should I look first.”

**2. narrow**
Uses investigation summaries for early narrowing. This solves “what level of evidence should I look at first.”

**3. pivot**
Moves across metrics, logs, traces, deployments, and other signals without losing investigation context.

**4. compare**
Compares suspect candidates and supports prioritization across deployments, downstream services, tenants, error paths, latency paths, and similar dimensions.

**5. continue**
Allows investigation to continue incrementally using the existing context, suspect set, and evidence set rather than reconstructing query context at every step.

#### Why this solves the problem

This layer directly addresses the problem in Section 2.2: lack of system support for cross-signal narrowing and candidate prioritization. The signal catalog solves discover. Summaries solve first narrowing. Execution primitives solve the ongoing narrowing / pivot / compare path. Without this layer, the catalog and summaries stored in Storage are only static objects and do not become part of the investigation path.

#### Non-goals

This section does not prescribe a specific UI and does not force a specific query syntax. PPL, DSL, or API can all carry these primitives. OpenSearch already has PPL and Event Analytics, which makes them natural candidates for investigation-aware execution.

---

### 6.4 Agent Integration

#### Goal

Allow the investigation process and its results to be consumed programmatically, not only through human interaction.

#### Proposed interfaces

**1. Investigation object API**
The system exposes stable investigation objects rather than only raw query entry points. Phase 1 includes at least: investigation context, suspect set, evidence set, and conclusion state.

**2. Machine-readable evidence contract**
Evidence output must be programmatically readable. Each evidence item includes at least: evidence type, related object, supporting signals, confidence / completeness, and conclusion impact.

**3. Programmatic state access**
An agent or workflow can read and update the current investigation state rather than relying on page state to indirectly drive the investigation.

**4. Shared model for human and agent**
The same investigation model serves UI, workflow, API, and agent consumers. The difference is consumption pattern, not object model.

#### Why this solves the problem

This layer directly addresses the gaps in Sections 2.1 and 2.3: neither humans nor agents naturally know where signals live, nor can they naturally inherit investigation state. Agent Integration does not generate evidence, but it makes the catalog, summaries, context, evidence, and conclusion state produced by earlier layers available as stable, consumable objects. OpenSearch already supports MCP / external MCP servers and agentic AI tools, which makes exposing the investigation model to agents an incremental extension rather than a new product category.

#### Non-goals

This section does not define a specific agent product shape and does not require all external agents to follow the same orchestration framework.

---

### 6.5 Governance

#### Goal

Make the usage boundaries of investigation outputs explicit so the system does not only produce results, but also constrains how those results are interpreted and used.

#### Proposed boundaries

**1. Evidence boundary**
Distinguish raw signal, derived evidence, supporting evidence, and insufficient evidence.

**2. Conclusion boundary**
At minimum distinguish `hypothesis`, `suspected cause`, `evidence-backed conclusion`, and `inconclusive`.

**3. Action boundary**
Distinguish which results are only suitable for analysis and which results may enter alert enrichment, routing, recommendation, or remediation workflows.

**4. Audit boundary**
The system must answer: what was checked, why the scope was narrowed, why a suspect was retained or excluded, and which evidence supports the current conclusion.

#### Why this solves the problem

This layer directly addresses Sections 2.3 and 2.4. The issue is not only that data is visible. The issue is that even when data is visible, the system often cannot clearly express what level of conclusion it supports, nor whether that conclusion is safe to use downstream. Governance makes evidence, conclusion, and action boundaries explicit, which makes investigation results auditable and reusable, and makes `inconclusive` a first-class outcome rather than a silent failure mode.

#### Non-goals

This section does not define organizational approval workflows and does not attempt to generalize all governance requirements into a cross-vendor standard.

---

## 7. How the Solution Addresses the Earlier Problems

| Problem                                                                         | Corresponding solution                                                       | How it resolves the problem                                                                                                                               |
| ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2.1 Lack of investigation entry, object identification, and context convergence | Signal catalog; Investigation context; Optional entry context enrichment     | The catalog makes signals discoverable; context preserves entry and scope; entry enrichment preserves the investigation start point when it is known.     |
| 2.2 Lack of cross-signal narrowing and candidate prioritization                 | Investigation summaries; Query / Execution primitives                        | Summaries provide early narrowing input; discover / narrow / pivot / compare / continue support continuous narrowing and candidate comparison.            |
| 2.3 Lack of investigation state, evidence, and conclusion boundary expression   | Investigation context; Evidence set; Conclusion state; Governance boundaries | The system persists checked scope, suspect set, evidence set, and conclusion state, and makes evidence / conclusion / action boundaries explicit.         |
| 2.4 Lack of consistent cross-system process semantics                           | Shared investigation model; Machine-readable evidence contract; OTel reuse   | Base signal semantics reuse OTel; OpenSearch defines a consistent investigation model and evidence contract for its own system and agent / API consumers. |

One point must be explicit: Section 2.4 is **not fully solved in phase 1**. This RFC takes a narrower approach: first establish a consistent investigation object model and evidence contract inside OpenSearch, aligned with OTel base semantics. Broader cross-vendor process semantic unification still depends on the continued evolution of the OpenTelemetry ecosystem.

---

## 8. Rollout and Prioritization

### P0

* Signal catalog
* Investigation summaries
* Query / Execution primitives: discover / narrow / pivot / compare / continue
* Investigation context, evidence set, conclusion state
* Evidence / conclusion / action boundaries

### P1

* Optional entry context enrichment
* Agent Integration APIs
* Machine-readable evidence contract
* MCP-oriented exposure of investigation objects

### P2

* Additional sketch types
* Broader agent telemetry alignment
* Wider cross-system process semantic alignment

The reasoning behind this order is simple. P0 establishes the minimum closed loop for the investigation path: discover, pre-narrowing, state, and boundaries. P1 makes that closed loop programmatically consumable. P2 expands the ecosystem alignment and richer capabilities. OpenSearch already has Data Prepper, Trace Analytics, PPL, MCP, and agentic AI integration, so this rollout can be implemented as an incremental evolution of the current product surface.

---

## 9. Non-goals

This RFC does not attempt to:

* redefine OTel base telemetry semantics
* reduce all observability problems to query latency optimization
* rewrite the underlying storage engine in phase 1
* build an “agent-only observability system” that is separate from human investigation
* fully standardize cross-vendor process semantics in phase 1

---

## 10. FAQ / Reference

### Q1. Is this problem only introduced by agents?

No. The problem already exists in human investigation, but is often partially masked by human experience and interactive exploration. Agents amplify it because they depend more directly on the system to expose objects, state, evidence, and boundaries. OpenTelemetry has already elevated AI agent observability as an independent topic, and Datadog publicly frames agent investigation as a continuous observation, reasoning, and action loop.

### Q2. Why not add many mirror fields in Ingestion?

Because OTel already covers a large portion of the foundational semantics. The problem is not a lack of field names. The problem is the lack of an investigation-ready organization layer. In phase 1, the real additions are the signal catalog and investigation summaries, not a second set of `service` / `environment` / `trace_id` mirror fields.

### Q3. Why do AQP / DataSketches appear in this RFC?

Because this RFC does not treat them as “just another query optimization topic.” It uses them in the early narrowing stage of investigation: identifying where anomalies are, which candidates are worth examining first, and which dimensions changed most. Data Prepper already supports deriving metrics and histograms from traces. DataSketches provide mergeable summaries, which makes them suitable for investigation summaries.

[1]: https://docs.opensearch.org/latest/observing-your-data/?utm_source=chatgpt.com "Observability"
[2]: https://opentelemetry.io/docs/concepts/semantic-conventions/?utm_source=chatgpt.com "Semantic Conventions"
[3]: https://newrelic.com/sites/default/files/2024-10/new-relic-2024-observability-forecast-report.pdf?utm_source=chatgpt.com "2024 Observability Forecast Report"
[4]: https://grafana.com/observability-survey/2025/?utm_source=chatgpt.com "Observability Survey Report 2025 - key findings"
[5]: https://docs.datadoghq.com/bits_ai/bits_ai_sre/investigate_issues/?utm_source=chatgpt.com "Investigate Issues"
[6]: https://docs.opensearch.org/latest/data-prepper/common-use-cases/trace-analytics/?utm_source=chatgpt.com "Trace analytics"
[7]: https://opentelemetry.io/docs/concepts/resources/?utm_source=chatgpt.com "Resources"
[8]: https://docs.opensearch.org/latest/observing-your-data/trace/getting-started/?utm_source=chatgpt.com "Getting started with Trace Analytics"
[9]: https://docs.opensearch.org/latest/data-prepper/common-use-cases/metrics-traces/?utm_source=chatgpt.com "Deriving metrics from traces"
[10]: https://opentelemetry.io/docs/concepts/signals/baggage/?utm_source=chatgpt.com "Baggage"
[11]: https://docs.opensearch.org/latest/observing-your-data/event-analytics/?utm_source=chatgpt.com "Event analytics"
[12]: https://docs.opensearch.org/latest/ml-commons-plugin/agents-tools/mcp/index/?utm_source=chatgpt.com "Using MCP tools"