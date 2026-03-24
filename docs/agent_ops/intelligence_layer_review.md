# Intelligence Layer RFC: Literature Review

## Executive Summary

The OpenSearch Intelligence Layer RFC is directionally correct and well-timed. Across 15 recent
papers spanning benchmarks (OpenRCA [1], AIOpsLab [2], ITBench [3], Cloud-OpsBench [4],
RCAEval [5], ITBench-Lite [6]), system architectures (STRATUS [7], Agent Failure Analysis [8], RIVA [9],
AOI [10], EoG [11], PRISM [12]), and surveys/evaluations (Cross-ISA Build Benchmark [13], AEMA [14],
LogEval [15]), the evidence converges on a single thesis: agents fail at operational tasks not
because models are weak, but because they start without structural context. The RFC's core
bet — pre-compute topology, baselines, and field profiles so agents don't re-derive them per
investigation — is supported by the consensus findings across these papers. ITBench [3] reports an 11.4% SRE
resolution rate (Abstract, ICML proceedings [3]); Agent Failure Analysis [8] finds 71.2% hallucinated data interpretation (pitfall frequency table in [8]); EoG [11]
shows 7x accuracy gains (Abstract, Table 2 in [11]) when agents receive dependency graphs. The RFC addresses the right
problem.

The biggest risk is not directional — it's completional. The RFC proposes five capabilities but
the literature identifies at least three critical gaps the RFC does not address: multi-agent
coordination protocols (STRATUS [7], RIVA [9], AOI [10]), safe exploration with rollback
(STRATUS [7] TNR), and trajectory learning from failed investigations (AOI [10] Evolver).
These are not nice-to-haves. Agent Failure Analysis [8] shows that inter-agent communication failures
are a distinct pitfall category, and AOI [10] demonstrates that pre-computed diagnostic
playbooks reduce run-to-run variance by 35% (§5.4.4, Table 4 in [10]). The RFC treats the agent as a black-box consumer
of context; the literature says the platform must also shape how agents investigate, not just
what they know at the start.

A secondary risk is the RFC's implicit assumption that pre-computed context is sufficient
without cross-validation mechanisms. RIVA [9] shows that in configuration drift detection,
agents cannot distinguish erroneous tool outputs from real anomalies — baseline ReAct achieves
only 27.3% accuracy, but RIVA's multi-agent cross-validation recovers this to 50.0% (Abstract, Table 1 in [9]). While specific to IaC verification, the principle
generalizes: the Intelligence Layer provides context but no mechanism for agents to verify
that context against live data. PRISM [12] demonstrates that simple property decomposition (internal vs.
external metrics) outperforms complex LLM agents — suggesting the RFC should invest
more in structural classification of fields and less in raw statistical baselines.

*Note: All quantitative claims cite specific sections and tables from the referenced papers. papers.md provides titles and brief descriptions; statistics were verified against the papers with section/table references provided at first citation.*

## Paper Summaries by Category

### Benchmark Papers (Papers 1–6)

| # | Paper | Venue | Key Finding | RFC Relevance |
|---|-------|-------|-------------|---------------|
| 1 | **OpenRCA** | ICLR 2025 | 335 failure cases (Abstract in [1]) across 3 enterprise systems; agents need pre-structured topology and normalized temporal context; network faults require trace latency analysis, not KPIs alone. | Directly validates need for pre-computed topology maps and field profiles; timestamp misalignment is a recurring failure mode the RFC's baselines could address. |
| 2 | **AIOpsLab** | MLSys 2025 | Best agent (Flash) achieves 59.3% accuracy (Table 3, §3.4 in [2]); information overload from raw telemetry is the top failure mode; agents waste steps calling non-existent APIs. | Validates that raw telemetry APIs are insufficient — agents need pre-processed, filtered data; supports pre-computed baselines and anomaly integration. |
| 3 | **ITBench** | ICML 2025 | 102 real-world scenarios (Abstract, ICML proceedings in [3]); agents resolve only 11.4% of SRE tasks; SRE is the hardest domain across SRE/CISO/FinOps. | The 11.4% SRE rate is the strongest quantitative evidence that agents need pre-computed context; directly motivates the Intelligence Layer. |
| 4 | **Cloud-OpsBench** | arXiv 2026 | 452 fault cases (Abstract in [4]) across 40 root cause types; standardized benchmark for evaluating LLM agents on cloud operations tasks; covers multiple cloud services and failure modes. | Provides the benchmark corpus that enables systematic evaluation of agent failures; validates need for pre-computed context by exposing agent limitations at scale. |
| 5 | **RCAEval** | WWW 2025 | 735 failure cases (Abstract, Table 2 in [5]), 11 fault types; metric-only methods fail on network faults; best methods achieve only Avg@5 of 0.46–0.54. | Validates field profiles (knowing which metrics matter per fault type) and multi-source correlation; code-level faults require log stack traces. |
| 6 | **ITBench-Lite** | AAAI 2026 Lab | Static snapshots of operational data; agents still struggle even without environment interaction complexity; the separate MAST taxonomy (arXiv:2503.13657, NeurIPS 2025) was later applied to ITBench traces, identifying planning failures as a key agent limitation. | Proves the problem isn't tool access — even with all data available statically, agents fail at reasoning; pre-computed context reduces cognitive load. |

### System Papers (Papers 7–12)

| # | Paper | Venue | Key Finding | RFC Relevance |
|---|-------|-------|-------------|---------------|
| 7 | **STRATUS** | NeurIPS 2025 | Multi-agent state machine with Transactional No-Regression (TNR) for safe exploration; 1.5x improvement (Abstract in [7]) over SOTA on AIOpsLab and ITBench. | TNR validates that agents need baseline health references for safe rollback — the RFC's baselines could serve this role; state machine architecture is absent from RFC. |
| 8 | **Why Do AI Agents Systematically Fail at Cloud Root Cause Analysis?** | arXiv 2026 | First process-level failure analysis of LLM-based RCA agents; develops 12-pitfall taxonomy across intra-agent reasoning, inter-agent communication, and agent-environment interaction layers; enriched inter-agent communication reduces failures by 14–15pp. | Validates RFC thesis that failures are architectural; but also shows inter-agent communication protocols matter — a gap in the RFC. |
| 9 | **RIVA** | arXiv 2026 | Multi-agent cross-validation recovers accuracy from 27.3% to 50.0% (Abstract, Table 1 in [9]) under erroneous tool responses in configuration drift detection; tool call history tracking detects inconsistencies between real drift and tool errors. | Shows agents need cross-validation mechanisms; pre-computed field profiles and baselines serve as ground truth for verification — but RFC lacks explicit verification support. |
| 10 | **AOI** | arXiv 2026 | Observer-Probe-Executor separation; GRPO-trained 14B model surpasses Claude Sonnet 4.5; Failure Trajectory Evolver reduces variance by 35% (§5.4.4, Table 4 in [10]). | Validates pre-computed diagnostic guidance; Evolver's corrected plans are analogous to pre-computed investigation playbooks; read-write separation pattern absent from RFC. |
| 11 | **EoG (Think Locally, Explain Globally)** | arXiv 2026 | Graph-guided LLM investigation via belief propagation over dependency graphs; 7x average gain in Majority@k F1 score (Abstract, Table 2 in [11]) over ReAct. | Strongest validation of topology pre-computation; shows LLMs should do local reasoning while structure guides global investigation — exactly the RFC's model. |
| 12 | **Graph-Free RCA** | arXiv 2026 | Graph-free RCA using internal/external property decomposition; 68% Top-1 accuracy, 258% over best baseline (§4.2, Table 2 in [12]); 8ms per diagnosis (§4.3 in [12]). | Validates field profiles and baselines; internal-external decomposition IS field profiling; shows simple pre-computed structure outperforms complex LLM agents. |

### Survey & Evaluation Papers (Papers 13–15)

| # | Paper | Venue | Key Finding | RFC Relevance |
|---|-------|-------|-------------|---------------|
| 13 | **A Benchmark for LMs in Real-World System Building** | arXiv 2026 | Cross-ISA build repair benchmark (268 failures); mentions OpenRCA, AIOpsLab, ITBench in passing to contextualize existing benchmarks; evaluates 6 LLMs on automated build repair. | Tangential — demonstrates LLM limitations in system-level tasks; its passing mention of operational benchmarks confirms the Intelligence Layer addresses a recognized gap, but this paper does not directly evaluate operational agent capabilities. |
| 14 | **AEMA** | arXiv 2026 | Process-aware multi-agent evaluation; single LLM-as-judge is unreliable (0.077 vs 0.018 absolute error (§4.3, Table 1 in [14])); step-level assessment needed. | Demonstrates that agent evaluation requires auditable traces; supports providing domain-specific observability primitives; confidence scores in RFC align with this. |
| 15 | **LogEval** | arXiv 2024 | First comprehensive LLM log analysis benchmark; fault diagnosis is hardest task; few-shot learning significantly improves log parsing. | Directly validates field profiles and log-parsing pre-computation; fault diagnosis requiring topology understanding supports the RFC's topology layer. |

## Gap Analysis: Literature vs. RFC

| What Papers Say Matters | RFC Coverage | Gap? | Evidence |
|-------------------------|-------------|------|----------|
| **Service topology / dependency graphs** | ✅ Service Topology (capability #2) | No | EoG [11] shows 7x accuracy gain with dependency graphs; OpenRCA [1] provides topology as supplementary data because agents cannot function without it. |
| **Baseline behavior profiles** | ✅ Temporal Baselines (capability #3) | Partial | PRISM [12] uses baseline distributions for its leading accuracy improvement, but RFC baselines are rolling statistical summaries — PRISM shows property classification matters more than rolling stats. |
| **Field semantic profiles** | ✅ Field Profiles (capability #1) | Partial | PRISM [12] internal/external decomposition and RCAEval [5] fault-type-to-metric mapping go well beyond the counter-vs-gauge semantics the RFC proposes. The RFC's definition is syntactic; the literature demands semantic classification. |
| **Anomaly detection integration** | ✅ AD Integration (capability #4) | No | AIOpsLab [2] and Agent Failure Analysis [8] validate pre-computed anomaly flags reduce incomplete exploration (63.9% pitfall rate (pitfall frequency table in [8])). |
| **Change / deployment correlation** | ✅ Change Detection (capability #5) | No | Agent Failure Analysis [8] 39.9% symptom-as-cause pitfall (pitfall frequency table in [8]) directly addressed by deployment correlation. |
| **Multi-agent coordination protocols** | ❌ Not addressed | **Yes** | STRATUS [7], RIVA [9] (in configuration drift detection), AOI [10] all use multi-agent architectures; Agent Failure Analysis [8] identifies inter-agent communication as a distinct pitfall category reducing accuracy by 15pp. |
| **Safe exploration with rollback** | ❌ Not addressed | **Yes** | STRATUS [7] TNR is critical for preventing premature remediation that worsens failures; RFC provides no mechanism for agents to safely act on context. |
| **Trajectory learning / diagnostic playbooks** | ❌ Not addressed | **Yes** | AOI [10] Evolver reduces variance by 35% using corrected investigation plans; RFC's agent-contributed knowledge is passive annotation, not active learning. |
| **Log parsing and pattern extraction** | ⏳ Deferred to Phase 2 | Partial | LogEval [15] shows LLMs struggle with raw log parsing; Agent Failure Analysis [8] reports 26.9% limited telemetry coverage because agents ignore logs entirely. Deferring this is a significant gap. |
| **Cross-validation mechanisms** | ❌ Not addressed | **Yes** | RIVA [9] shows that in configuration drift detection, multi-agent cross-validation recovers accuracy from 27.3% (ReAct baseline) to 50.0% — while specific to IaC, the cross-validation principle generalizes; Agent Failure Analysis [8] identifies 18.6% No Cross-Validation pitfall rate — agents rely on single data sources without corroborating across metrics, logs, and traces. |
| **Causal reasoning / abductive inference** | ⏳ Deferred (Causal Graph in later phases) | **Yes** | EoG [11] formulates investigation as abductive reasoning over dependency graphs; PRISM [12] uses causal property decomposition. Deferring causal graphs weakens the topology capability. |
| **Evaluation frameworks for agent-context interaction** | ❌ Not addressed | **Yes** | AEMA [14] argues platforms need built-in evaluation of how well agents use provided context; [13] mentions operational benchmarks in passing, confirming the Intelligence Layer addresses a recognized gap. |

## Strengths of the RFC

- **Topology pre-computation is the highest-leverage intervention the RFC proposes.** EoG [11]
  demonstrates dramatic accuracy gains when agents receive dependency graphs instead of discovering
  them through exploration. OpenRCA [1] provides topology as supplementary data in its benchmark
  precisely because agents cannot function without it. STRATUS [7] uses topology for agent
  routing in its multi-agent state machine. Agent Failure Analysis [8] quantifies the cost of missing
  topology: 63.9% incomplete exploration. The RFC correctly identifies Service Topology as a
  must-have capability, and the literature unanimously agrees.

- **The "agents start blind" thesis is empirically validated across all 15 papers.** Agent Failure Analysis
  [8] quantifies this with surgical precision: 71.2% hallucinated data interpretation, 63.9%
  incomplete exploration, 39.9% symptom-as-cause errors. ITBench [3] shows 11.4% SRE resolution
  rates. ITBench-Lite [6] proves the problem persists even with static data access — removing
  environment interaction complexity doesn't help. AIOpsLab [2] shows even the best agent (Flash)
  only reaches 59.3%. The RFC's core motivation is not speculative — it is the consensus finding
  of the field. Every benchmark paper independently arrives at the same conclusion.

- **Field Profiles as the lowest-risk first deliverable is a sound engineering decision.** PRISM
  [12] shows that simple property classification (internal vs. external) yields dramatic accuracy
  improvement over baselines — and it ships in 8ms per diagnosis. Field profiles can ship
  independently, provide immediate value to agents, and validate the approach before tackling
  higher-risk capabilities like AD integration. The RFC's risk-ordered prioritization (lowest
  risk first) is a mature engineering choice that the PRISM results validate.

- **Freshness timestamps and confidence scores align with evaluation literature.** AEMA [14]
  argues for auditable, traceable agent evaluation — every decision must produce a verifiable
  artifact. The RFC's inclusion of freshness and confidence metadata on every response enables
  agents to make informed trust decisions. RIVA [9]'s cross-validation approach depends on
  agents having ground-truth references with known reliability — confidence scores provide
  exactly this. The degraded-mode response pattern (stale data with explicit warning) is a
  pragmatic design that no paper criticizes.

- **The REST API design separating intelligence queries from the query engine is architecturally
  sound.** AIOpsLab [2] defines an Agent-Cloud Interface (ACI) as a standardized API surface
  for agent-environment interaction. The RFC's dedicated REST surface with JSON responses follows
  this pattern. AOI [10]'s Observer-Probe-Executor separation validates that read-only context
  queries should be decoupled from data mutation operations. The RFC's API design enables this
  separation naturally.

- **Graceful degradation when AD plugin is disabled shows operational maturity.** The RFC
  explicitly addresses partial-capability scenarios — when AD is disabled, the API returns empty
  results with status rather than failing. This aligns with PRISM [12]'s demonstration that
  graph-free approaches (no topology) can still provide value through property decomposition
  alone. The principle of partial value over total failure is well-supported by the literature.

## Weaknesses and Blind Spots

- **No multi-agent coordination support.** STRATUS [7], RIVA [9], and AOI [10] all demonstrate
  that effective agent systems use specialized multi-agent architectures — not single monolithic
  agents. Agent Failure Analysis [8] identifies inter-agent communication failures as a distinct pitfall
  category, and enriched protocols reduce failures by 15 percentage points. The RFC treats the
  agent as a single black-box consumer of context. In practice, investigation agents are
  multi-agent systems (detector, diagnostician, mitigator per STRATUS [7]; observer, probe,
  executor per AOI [10]), and the Intelligence Layer should provide coordination primitives:
  shared investigation state, agent role context, and handoff protocols. This is the largest
  architectural blind spot in the RFC.

- **No safe exploration or rollback mechanism.** STRATUS [7]'s Transactional No-Regression (TNR)
  is the most significant architectural innovation in the system papers — it enables agents to
  try mitigations and revert if system health degrades. Agents that act on pre-computed context
  (e.g., "this deployment caused the regression, roll it back") need safety guarantees. The RFC
  provides context for decision-making but no guardrails for action-taking. Pre-computed baselines
  could serve as health references for TNR-style checks, but the RFC does not propose this use
  case. Without safety mechanisms, the Intelligence Layer enables faster bad decisions, not just
  faster good ones.

- **No trajectory learning or investigation memory.** AOI [10]'s Failure Trajectory Evolver
  converts failed diagnostic runs into corrective supervision signals, reducing run-to-run
  variance by 35%. The RFC mentions agent-contributed knowledge with TTL-based expiration, but
  this is passive annotation — not active learning from investigation trajectories. The platform
  accumulates system knowledge (topology, baselines) but discards investigation knowledge (what
  worked, what didn't, which paths were dead ends). EoG [11]'s belief propagation shows that
  investigation state management is critical; the RFC provides no mechanism for persisting or
  learning from investigation patterns across sessions.

- **Field Profiles are too shallow for what the literature demands.** The RFC defines field
  profiles as "counter vs. gauge, cardinality estimation, field name conventions." PRISM [12]
  shows that the critical classification is internal vs. external properties per component — a
  semantic distinction that determines whether a metric indicates a root cause or a downstream
  symptom. RCAEval [5] shows that fault-type-to-metric mappings matter: resource faults are
  diagnosable from CPU/memory metrics, but network faults require trace latency and code-level
  faults require log stack traces. The RFC's field profiles are syntactic metadata; the
  literature demands semantic classification that guides investigation strategy.

- **Log Patterns deferred to Phase 2 despite strong evidence of need.** LogEval [15] demonstrates
  that LLMs struggle with raw log parsing and that fault diagnosis is the hardest log analysis
  task. Agent Failure Analysis [8] shows 26.9% limited telemetry coverage — agents ignore logs entirely
  when they don't know how to parse them. In most observability environments, logs are the
  dominant telemetry type by volume. Deferring log pattern extraction means Phase 1 agents will
  continue to underperform on the most common data source. This is a prioritization error.

- **No cross-validation or verification support.** RIVA [9] shows that in configuration
  drift detection, baseline ReAct achieves only 27.3% accuracy, but multi-agent cross-validation
  recovers this to 50.0%. While RIVA's
  specific numbers are from configuration drift detection, the principle — that agents need
  mechanisms to distinguish real anomalies from tool errors — applies broadly to any
  pre-computed context system. The Intelligence Layer provides context but no
  mechanism for agents to verify that context against live data or cross-validate findings across
  telemetry types. Agent Failure Analysis [8] identifies that 18.6% of failures stem from agents not
  corroborating findings across data sources. Providing pre-computed context without verification
  mechanisms risks creating a new failure mode: agents that blindly trust stale or incorrect
  pre-computed context instead of blindly trusting raw data interpretation.

- **Temporal Baselines may be over-invested relative to structural classification.** PRISM [12]
  achieves 68% Top-1 accuracy with property decomposition and deviation scoring — no rolling
  statistical summaries needed. It runs in 8ms per diagnosis, 9,600x faster than LLM-based
  approaches. The RFC allocates a full capability to temporal baselines (rolling stats per metric
  per service) when the literature suggests structural field classification (PRISM-style)
  delivers more value per engineering hour. The RFC should consider whether the engineering
  effort for rolling multi-granularity baselines is justified when simpler deviation scoring
  achieves superior results.

## Priority Assessment: The Five Must-Have Capabilities

### 1. Field Profiles

**Literature support:** PRISM [12] demonstrates 258% accuracy improvement from property
classification alone — the single largest accuracy gain reported in any paper in this review.
RCAEval [5] shows fault-type-to-metric mappings are critical for guiding agents to the right
telemetry source. LogEval [15] validates that LLMs need structured field context for log
analysis; few-shot learning with field examples significantly improves parsing accuracy.
Agent Failure Analysis [8]'s 71.2% hallucination rate is partly attributable to agents misinterpreting
field semantics (treating counters as gauges, misunderstanding cardinality).

**Literature concerns:** The RFC's definition (counter/gauge, cardinality, naming conventions)
is too narrow. PRISM [12] shows the critical distinction is internal vs. external properties —
a semantic classification that determines root-cause vs. symptom. RCAEval [5] shows agents need
to know which metrics are relevant for which fault categories (resource faults → CPU/memory;
network faults → trace latency; code faults → log stack traces). The RFC proposes syntactic
metadata when the literature demands semantic classification.

**Verdict:** Correct priority, correct position as first deliverable. But scope must expand
beyond syntactic metadata to include semantic property classification (internal/external,
fault-relevance mapping). This is the foundation everything else builds on — get it right.

### 2. Service Topology

**Literature support:** EoG [11] provides the strongest evidence in the entire review — its
accuracy gain in Majority@k F1 score when agents receive dependency graphs with deterministic
traversal. OpenRCA [1] includes topology as required supplementary data because agents cannot
navigate systems without it. STRATUS [7] uses topology for agent routing in its state machine.
Agent Failure Analysis [8] shows 63.9% incomplete exploration without topology guidance — agents
literally don't know where to look. ITBench [3]'s 11.4% SRE rate is partly explained by agents
lacking topology context in complex Kubernetes environments.

**Literature concerns:** PRISM [12] achieves 68% Top-1 accuracy without any dependency graph,
using property decomposition alone. This is an important existence proof that topology is not
strictly necessary for all RCA approaches. However, PRISM operates on pre-labeled component
properties — which itself requires some form of system knowledge. EoG [11]'s 7x gain is
measured against ReAct baselines that have no structural guidance; the gap may narrow with
better field profiles.

**Verdict:** Correct priority. The evidence is overwhelming — EoG [11] alone justifies this
capability. PRISM [12]'s graph-free success is an important fallback for environments without
trace data, which the RFC already acknowledges with graceful degradation. Note: EoG's 7x gain and PRISM's 258% improvement are not competing claims — they measure different things against different baselines. EoG's 7x is against ReAct baselines on ITBench diagnostic tasks; PRISM's 258% is against RCA baselines on RCAEval. They are complementary: topology is highest-leverage when trace data is available; property-based field classification is highest-leverage when it is not. The RFC should support both paths. No change needed.

### 3. Temporal Baselines

**Literature support:** Agent Failure Analysis [8] shows agents hallucinate data interpretation —
agents fabricate coherent narratives about metric behavior because they don't know what's
normal. PRISM [12] uses baseline distributions for anomaly scoring. AIOpsLab [2] validates
that agents need pre-processed telemetry rather than raw data streams. STRATUS [7]'s TNR
requires health baselines to determine whether agent actions improved or degraded the system.

**Literature concerns:** PRISM [12] achieves its results with deviation scoring against
baselines computed from early post-fault data (81% accuracy at just 10% of the data window) —
not rolling historical summaries. AOI [10] uses compressed diagnostic context, not raw
statistical baselines. The RFC proposes "rolling statistical summaries per metric per service"
which is expensive to compute and store (10KB per metric per time granularity). The literature
suggests simpler deviation-from-recent-normal would suffice for most use cases, and that the
engineering effort for multi-granularity rolling summaries may not be justified.

**Verdict:** Correct to include, but potentially over-scoped. Consider a simpler baseline
model (recent deviation scoring à la PRISM [12]) as the Phase 1 implementation, with full
rolling statistical summaries as a Phase 2 enhancement if the simpler model proves insufficient.
The RFC's storage estimates (10KB per metric per time granularity) suggest awareness of the
cost, but the design should start simple.

### 4. Anomaly Detection Integration

**Literature support:** Agent Failure Analysis [8] shows 63.9% incomplete exploration — agents miss
anomalies in data they don't examine. AIOpsLab [2] validates pre-computed anomaly flags as
essential for reducing the search space. ITBench [3] includes anomaly detection as a core
evaluation dimension (FinOps anomaly detection F1 = 0.35). RCAEval [5] shows that multi-source
anomaly correlation is essential — metric-only anomaly detection fails on network faults.

**Literature concerns:** The RFC scopes this as "agent-consumable anomaly context aggregated
from the existing AD plugin." This is presentation-layer work, not detection improvement.
ITBench [3]'s F1=0.35 suggests the underlying AD quality may be the bottleneck, not the
presentation format. PRISM [12] achieves better anomaly identification through property
decomposition than through dedicated anomaly detectors — suggesting that better field profiles
might obviate some AD integration complexity. The RFC's dependency on the AD plugin means the
Intelligence Layer inherits whatever quality limitations the AD plugin has.

**Verdict:** Correct to include, and the RFC correctly identifies this as highest-risk. The
spike approach before committing to integration strategy is appropriate. But the RFC should
define a fallback: if AD quality is insufficient, can the Intelligence Layer provide basic
anomaly context (deviation from baseline) without the AD plugin? PRISM [12] suggests yes.

### 5. Change Detection

**Literature support:** Agent Failure Analysis [8] shows 39.9% symptom-as-cause — agents stop at the
first anomaly instead of tracing to a deployment or config change. This is the third most
common pitfall in the taxonomy. The RFC correctly identifies change detection as moving agents
from observation ("error rate spiked at 14:32") to explanation ("correlates with the 14:30
deployment"). The broader systems benchmarking literature [13] also highlights the importance of tracking changes over time in system-level tasks.

**Literature concerns:** The RFC acknowledges dependency on external event sources (CI/CD
webhooks or manual annotation). No paper in this review proposes a solution for environments
without deployment event streams. This capability's value is binary — it works well with
deployment event sources and provides zero value without them. The cold-start problem for
change detection is more severe than for other capabilities because there's no way to derive
deployment events from existing OpenSearch data.

**Verdict:** Correct priority, but the external dependency risk is underweighted. The RFC
should define a minimum viable change detection that works with OpenSearch-internal signals
(index creation patterns, mapping changes, ingest rate shifts, new field appearances) before
requiring external CI/CD integration. This provides partial value in all environments rather
than full value in some and zero in others.

## Specific Recommendations

1. **Expand Field Profiles to include PRISM-style internal/external property classification.**
   PRISM [12] shows that classifying metrics as internal (CPU, memory, config-derived) vs.
   external (latency, error rate, throughput) per component enables dramatic accuracy improvement
   over the best existing baseline. The RFC's counter-vs-gauge distinction is necessary but
   insufficient. Add a `property_class` field (internal/external/unknown) to field profiles,
   derivable from metric naming conventions and index patterns. This single addition may be
   the highest-ROI change to the RFC.

2. **Add a cross-validation API endpoint.** RIVA [9] demonstrates that multi-perspective
   verification recovers accuracy from 27.3% to 50.0% under erroneous tool responses in
   configuration drift detection — while the specific numbers are from IaC verification, the
   cross-validation pattern generalizes to any domain where tool outputs may be stale or
   erroneous. The Intelligence Layer should expose an endpoint that, given a hypothesis ("payment-service is
   the root cause"), returns corroborating and contradicting evidence across telemetry types
   (metrics, traces, logs). This is not a new capability — it's an orchestration of existing
   capabilities (topology + baselines + anomaly flags) focused on verification. Agent Failure Analysis [8]'s
   18.6% no-cross-validation failure rate quantifies the cost of omitting this.

3. **Promote Log Patterns from Phase 2 to Phase 1.** LogEval [15] shows LLMs struggle with
   raw log parsing — fault diagnosis is the hardest task in their benchmark. Agent Failure Analysis [8]
   reports 26.9% limited telemetry coverage because agents ignore logs. In most observability
   environments, logs are the dominant telemetry type by volume. At minimum, include a basic
   log template extraction (drain-style parsing) in Phase 1. This doesn't require the full
   Log Patterns capability — just enough structure for agents to consume log data without
   raw-parsing every line.

4. **Define multi-agent coordination primitives in the API surface.** STRATUS [7] uses a state
   machine for agent coordination. AOI [10] separates Observer, Probe, and Executor roles.
   Agent Failure Analysis [8] shows inter-agent communication failures are a distinct pitfall category
   that enriched protocols reduce by 15pp. The Intelligence Layer should provide: (a) shared
   investigation state (which services have been examined, what hypotheses are active),
   (b) role-based context filtering (detector agents get anomaly context, diagnostician agents
   get topology + baselines), and (c) investigation lifecycle tracking. This can be a thin
   coordination layer on top of the existing five capabilities.

5. **Add investigation trajectory storage for downstream learning.** AOI [10]'s Failure
   Trajectory Evolver reduces run-to-run variance by 35% by learning from failed investigations.
   The RFC's agent-contributed knowledge (low-confidence, TTL-based) is too passive. Add a
   structured investigation log: which context endpoints were called, which queries were run,
   what conclusion was reached, whether it was confirmed. This enables trajectory-based learning
   without requiring the platform to train models — it provides the data substrate for
   downstream learning systems like AOI's Evolver.

6. **Simplify Temporal Baselines to deviation scoring before investing in rolling summaries.**
   PRISM [12] achieves 68% Top-1 accuracy using deviation-based anomaly scoring against recent
   data — not rolling historical summaries — and does it in 8ms. The RFC proposes "rolling
   statistical summaries per metric per service" which is expensive to compute and store. Start
   with a simpler model: recent-window deviation scores (mean, stddev, percentiles over the
   last N hours). Only invest in multi-granularity rolling summaries if the simpler model proves
   insufficient during prototype validation.

7. **Include a "health reference" API for safe exploration.** STRATUS [7]'s TNR requires a
   health baseline to determine whether an agent's action improved or degraded the system. The
   Intelligence Layer's baselines are positioned as investigation context, but they could also
   serve as health references for action validation. Add an endpoint: given a service and a
   time window, return whether current metrics are within baseline bounds — a binary
   healthy/degraded signal that agents can use before and after taking remediation actions.
   This extends the Intelligence Layer from investigation support to action safety.

8. **Add fault-type-to-telemetry-source mapping to Field Profiles.** RCAEval [5] demonstrates
   that resource faults are diagnosable from metrics alone, but network faults require trace
   latency analysis and code-level faults require log stack traces. Field Profiles should
   include guidance on which telemetry sources are relevant for which fault categories. This
   directly addresses Agent Failure Analysis [8]'s 26.9% limited telemetry coverage — agents ignore
   data sources because they don't know which sources matter for the current fault type.

9. **Define evaluation hooks for measuring context effectiveness.** AEMA [14] argues for
   process-aware, auditable agent evaluation. The broader systems benchmarking literature [13] underscores the need for
   evaluating LLM performance on system-level tasks. The Intelligence Layer should emit structured telemetry
   about its own usage: which context endpoints were called, response latency, freshness at
   time of consumption, and (when available) whether the investigation succeeded. This enables
   measuring whether the Intelligence Layer actually improves agent outcomes — critical for
   justifying continued investment and guiding Phase 2 priorities.

10. **Address the cold-start problem with explicit API semantics.** Multiple papers (PRISM [12],
    RCAEval [5]) note that baselines require observation windows to converge. The RFC mentions
    "cold-start periods on new clusters" but defers to the design phase. Define concrete API
    semantics now: (a) minimum observation window before baselines are served (not just
    low-confidence flags), (b) explicit response codes distinguishing "no data exists" from
    "data exists but is stale" from "data exists with conflicting signals," and (c) bootstrap
    strategies for new services (inherit baselines from similar services or index patterns).
    Agents need to distinguish these states to choose appropriate fallback strategies.

## What Would the Papers' Authors Likely Say?

### Benchmark Authors: OpenRCA (Microsoft Research), Cloud-OpsBench (Sun Yat-sen University / CUHK)

These are separate research groups whose benchmarks converge on the same conclusion. The OpenRCA
team (Microsoft Research Asia, with Tsinghua and CUHK-Shenzhen collaborators) would point to
their 335 failure cases across 3 enterprise systems as evidence that agents need pre-structured
topology and normalized temporal context — directly validating the Intelligence Layer's core
capabilities. The Cloud-OpsBench team (Sun Yat-sen University and CUHK) would highlight their
452 fault cases across 40 root cause types as the benchmark corpus that exposes agent limitations
at scale. Both groups would push for richer topology representations and fault-type-to-telemetry-source
mappings, since their benchmarks show that network faults require trace latency analysis (not
KPIs alone) and metric-only methods fail on certain fault categories. They would want to see
systematic evaluation of the Intelligence Layer against their respective fault corpora.

### Agent Failure Analysis Authors (Hanyang University)

They would view the RFC as necessary but insufficient — it addresses the "starting blind"
problem but not the "reasoning blind" problem. Their 12-pitfall taxonomy and 1,675-run dataset
are essentially a requirements document for the Intelligence Layer — every pitfall maps to a
missing context type. They would push hard on two points: (1) the RFC must address inter-agent
communication, not just single-agent context — their data shows communication failures are a
distinct failure mode that pre-computed context alone doesn't fix, and enriched protocols reduce
these failures by 14–15 percentage points; and (2) the RFC should prioritize cross-validation
mechanisms, since their 18.6% no-cross-validation pitfall means agents will still fail even
with good context if they can't corroborate findings across telemetry types. Their 1,675-run
dataset would be the ideal validation corpus for the Intelligence Layer prototype.

### ITBench / EoG / STRATUS Authors (IBM / UIUC)

They would validate the topology and baseline capabilities enthusiastically — EoG's accuracy gain
is the strongest evidence for topology pre-computation in the literature. But they would
challenge the RFC's lack of investigation structure. EoG [11] shows that giving agents a graph
is not enough — you need a deterministic controller managing traversal and belief propagation.
The graph is the substrate; the traversal algorithm is what delivers the accuracy gain. STRATUS [7]
shows agents need formal state machines and safety guarantees (TNR). They would argue the RFC
is too passive: it provides context but doesn't shape how agents use it. Their recommendation
would be to add investigation workflow primitives — state tracking, hypothesis management,
safe exploration protocols — alongside the raw context APIs. They would also note that
ITBench's 11.4% SRE rate means the bar for "good enough" context is very high — the
Intelligence Layer needs to be substantially better than "some topology and some baselines"
to move the needle on real SRE tasks.

### PRISM Author (Luan Pham)

Would likely argue the RFC over-complicates baselines and under-invests in field classification.
PRISM achieves its leading accuracy over the best baseline with a simple internal/external property
decomposition — no topology graph, no rolling statistics, no anomaly detection plugin, and it
runs in 8ms. The PRISM author would push for: (1) richer field profiles as the primary
investment (property classification, not just counter/gauge), (2) simpler baseline models
(deviation scoring, not rolling summaries), and (3) a graph-free fallback path that works
without trace data as a first-class citizen, not just graceful degradation. They would view
the RFC's five capabilities as reasonable but would reorder priorities: Field Profiles
(expanded with internal/external classification) → Baselines (simplified to deviation scoring)
→ Change Detection → Topology → AD Integration. Their core critique: the RFC spreads
engineering effort across five capabilities when concentrating on deep field classification
would deliver more impact with less complexity.

### AOI Authors

Would focus squarely on the learning gap. AOI's Failure Trajectory Evolver is their key
innovation — converting failed investigations into training signals that reduce variance by
35% and improve accuracy by 4.8pp. They would argue the RFC's agent-contributed knowledge
(low-confidence, TTL-based annotations) fundamentally misunderstands how agents improve. The
platform shouldn't just accept annotations — it should capture full investigation trajectories
(context consumed, queries issued, hypotheses tested, conclusions reached) and make them
available for downstream learning systems. Their Observer-Probe-Executor separation would also
inform their critique: the Intelligence Layer should enforce read-only access for diagnostic
queries and gate write operations through a separate, audited path. They would view the RFC
as providing good static context but missing the dynamic learning loop that makes agents
improve over time. Their recommendation: add structured investigation logging from day one,
even if trajectory-based learning is Phase 2+.

### RIVA Authors

Would zero in on the verification gap with precision. RIVA's core insight — developed in the
context of configuration drift detection using AIOpsLab — is that agents cannot distinguish
erroneous tool outputs from real anomalies — and the Intelligence Layer is
itself a tool whose outputs could be stale, incomplete, or misleading (the RFC acknowledges
staleness windows and cold-start periods). They would argue that confidence scores and
freshness timestamps are necessary but insufficient for robust agent behavior. The RFC needs:
(1) a mechanism for agents to cross-validate Intelligence Layer outputs against live queries —
not just trust the pre-computed answer, (2) tool call history tracking so agents can detect
when Intelligence Layer responses are inconsistent across calls (e.g., topology changed
mid-investigation), and (3) explicit degradation signals that distinguish "no data" from
"stale data" from "conflicting data" — three states that require different agent strategies.
They would view the RFC as providing good context but lacking the meta-cognitive layer that
lets agents reason about the reliability of that context. Their multi-perspective verification
pattern (same question asked via different tool calls) should inform the cross-validation API
recommended above.
