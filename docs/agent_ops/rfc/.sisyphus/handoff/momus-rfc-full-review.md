# RFC Full-Document Review: OpenSearch Agent Observability Investigation Framework v0.1

**Reviewer:** Momus v3 (full-document pass)
**Rating:** ⭐⭐⭐ (OKAY — Workable with Risk)
**Previous:** v1 ⭐⭐⭐, v2 ⭐⭐⭐⭐ (DataSketches-only refresh)

---

## VERDICT: OKAY ⭐⭐⭐

### Summary

The RFC articulates a genuine gap — investigation as a first-class system object — with strong external evidence. But it is 60% problem statement and 40% solution sketch. Solution sections name constructs (signal catalog, 5 primitives, evidence states) without specifying schemas, APIs, PPL syntax, state transitions, or index mappings. An implementer would know *what* to build but not *how*. Two cited statistics are unverifiable. The companion DataSketches design proves one subsystem is feasible but remains unintegrated.

---

## Per-Section Review

### Abstract

**What works:** Correctly frames the gap as organizational ("not yet organized into a reusable investigation process") rather than capability-based. Names all 4 core constructs. States the OTel reuse posture upfront.

**Issues:**
- At ~180 words, it's dense but acceptable for an RFC.
- The phrase "investigation-first system structure" is the RFC's key concept but is never formally defined. It appears 3 times across the document without a definition.
- Minor: "MCP / agentic AI integration" is listed as an existing building block but MCP is only available since OpenSearch 3.0 (ref12). The abstract implies it's established infrastructure.

### Section 1: Problem Statement

**What works:** The 4-paragraph structure (fragmentation → cost/scale → result shape → auditability) is logical. External citations ground each claim. The bold thesis statement at the end is precise and well-scoped.

**Issues:**
- **[CRITICAL] Two unverifiable statistics.** "88% of respondents use two or more monitoring tools" and "34% identify too many tools and data silos" are attributed to New Relic 2024. The ref03 summary contains neither figure. The closest New Relic stats are: 45% use 5+ tools, 41% plan to consolidate. These must be fixed or removed.
- **[MISLEADING]** "Grafana's follow-up cost management article also states that 74%..." — this is from the Grafana 2025 survey itself (ref04), not a separate article. Reads as independent corroboration when it's the same source.
- **Overlong.** ~800 words for a problem statement. The first paragraph restates the abstract. Paragraphs 3-4 could be compressed by 40%.
- **OTel maturity overstated.** "OpenTelemetry, in elevating AI agent observability as a distinct topic in 2025" — ref02 shows GenAI as one row in a semantic conventions table (emerging status), not a major published initiative.
- The LangChain/LangSmith reference (para 3) is uncited — no reference entry for it.

### Section 2: Problem Breakdown (2.1–2.4)

**What works:** The 4 sub-problems are well-decomposed and mostly non-overlapping. Each follows a consistent pattern: describe the gap → explain why it matters → state the missing capability. Section 2.1's insight that "neither humans nor agents naturally know where signals live" is the RFC's strongest observation.

**Issues:**
- **Redundancy with Section 1.** The intro paragraph of Section 2 restates the Section 1 thesis nearly verbatim. The "Therefore" conclusions of 2.1–2.3 each restate their own section's opening.
- **2.1 vs 2.2 overlap.** "Context convergence" (2.1) and "cross-signal narrowing" (2.2) share significant territory — both involve moving across signal types to focus investigation. The distinction is temporal (entry vs. ongoing) but not made crisp.
- **2.4 is underspecified.** "Different systems do not model concepts such as task, step, tool call, memory, artifact, and action in the same way" — which systems? What specific incompatibilities? This reads as a placeholder for a real analysis. The RFC later acknowledges (Section 7) that 2.4 is not fully solved in Phase 1, which raises the question of whether it belongs in the problem statement at all.
- **No prioritization.** All 4 problems are presented as equally important. Are they? Section 8 (Rollout) implicitly prioritizes 2.1–2.3 over 2.4, but Section 2 doesn't signal this.

### Section 3: Module Matrix

**What works:** The problem×layer matrix is a useful structural device. The 3-point interpretation paragraph adds value.

**Issues:**
- **Ratings are unjustified.** Why is Ingestion "High" for 2.1 but "Medium" for 2.2? Why is Governance "Low" for 2.1 but "High" for 2.3? No rationale is given for any cell. A reader must trust the author's judgment without evidence.
- **Missing row/column definitions.** "Ingestion," "Storage," etc. are not defined until Section 6. The matrix forward-references undefined terms.
- **Actionability is low.** The matrix tells you where problems land but not what to do about it. It would be more useful if each High cell linked to a specific solution component.

### Section 4: Current State

**What works:** Correctly identifies the gap as organizational rather than capability-based. The bold statement ("existing capabilities have not yet been organized into an investigation-first system structure") is the RFC's clearest formulation.

**Issues:**
- **Incomplete inventory.** The RFC lists "OTel-based trace ingestion, Data Prepper pipelines, Trace Analytics, Event Analytics, Metrics Analytics, PPL, support for deriving metrics and histograms from traces, and MCP / agentic AI integration." Missing from this list (per ref01):
  - SS4O (Simple Schema for Observability) — the standardized schema convention
  - Application Analytics — groups logs/traces/metrics by application
  - Anomaly Detection — ML-based anomaly detection with alerting integration
  - Notebooks — combine visualizations + code blocks
  - Alerting monitors (per-query, per-bucket, composite)
  - OpenSearch Assistant / Query Assistant (NL→PPL)
  - Log-trace correlation via TraceId
  These omissions matter because several (Application Analytics, Notebooks, Alerting) are partial solutions to problems the RFC claims are unsolved.
- **No mention of existing agent tools.** Ref12 shows OpenSearch already exposes 30+ built-in tools via MCP (SearchIndexTool, PPLTool, SearchAlertsTool, SearchAnomalyDetectorsTool, etc.). The RFC should acknowledge these as the baseline for Section 6.4.
- **Too short.** At ~120 words, this section doesn't do justice to what OpenSearch already has. A reader unfamiliar with OpenSearch gets no useful picture of the starting point.

### Section 5: Design Principles (5.1–5.6)

**What works:** 5.1 ("center on investigation path") and 5.6 ("evolve incrementally on existing stack") are genuinely useful constraints that would help an implementer make tradeoff decisions. 5.5 ("make evidence/conclusion/action boundaries explicit") is the most distinctive principle — it differentiates this RFC from generic observability improvements.

**Issues:**
- **5.2–5.4 are platitudes.** "Prioritize shared capabilities for humans and agents" (5.2), "Make process explicit" (5.3), "Prioritize programmatic consumption" (5.4) — these restate the problem as a principle. They don't help make design decisions. Test: could a reasonable person disagree with any of these? No. That means they're not constraining.
- **No anti-principles.** What does this RFC explicitly *not* optimize for? E.g., "We do not optimize for real-time streaming investigation" or "We do not prioritize backward compatibility with existing dashboard layouts." Anti-principles are more useful than motherhood statements.
- **No conflict resolution.** 5.2 ("shared for humans and agents") and 5.4 ("prioritize programmatic consumption") can conflict — what happens when the best human UX diverges from the best API shape? No guidance.
- **Missing: performance/cost principle.** Given that Section 1 spends a full paragraph on cost pressure (17% of compute spend, 74% cite cost), there's no principle about cost-efficiency or resource overhead of the investigation layer itself.

### Section 6.1: Ingestion

**What works:** The 3 additions (signal catalog, investigation summaries, entry context enrichment) are well-scoped. The reuse posture ("does not add mirror fields") is correct and clearly stated. The non-goals are appropriate. The note that metadata "can be constructed in the pipeline rather than inferred ad hoc at query time" correctly identifies Data Prepper as the right place.

**Issues:**
- **Signal catalog population is unspecified.** "This metadata can be constructed in the pipeline" — which pipeline? A new Data Prepper processor? An extension to an existing one? What events trigger catalog updates? How is staleness handled? This is the most important new construct in the RFC and it has zero implementation detail.
- **"Investigation summaries" conflates two very different things.** "Derived metrics/histograms" already exist in Data Prepper (ref09 documents the `aggregate` processor with `histogram` action). "Mergeable sketches" require new infrastructure (DataSketches library integration). Grouping them as one item obscures the fact that one is incremental and the other is a significant engineering effort.
- **Entry context enrichment via OTel baggage has security implications.** Ref10 explicitly warns: baggage is plaintext in HTTP headers, propagated to all outbound requests including third-party APIs, with no authentication or integrity mechanism. The RFC should acknowledge this and recommend opaque IDs only.
- **No Data Prepper pipeline config shown.** Even a sketch of the pipeline YAML would clarify the design. The companion DataSketches design (file #4, §2.2) has this — the RFC doesn't.

### Section 6.2: Storage

**What works:** The 4 storage objects are logically complete — they cover discovery (catalog), pre-computation (summaries), state (context), and judgment (evidence/conclusion). The 5-state conclusion model (open/narrowed/suspected/inconclusive/concluded) is well-designed, and citing Datadog's explicit `inconclusive` pattern is good precedent.

**Issues:**
- **No index mappings.** This is an OpenSearch RFC. Index mappings are the most fundamental design artifact. None are provided for any of the 4 storage objects. The companion design (file #4, §3) provides one for sketches — the RFC should do the same for all objects.
- **No state transition rules.** Can an investigation go from `concluded` back to `open`? From `suspected` to `inconclusive`? Who/what triggers transitions? Without a state machine, the 5 states are just labels.
- **No concurrency model.** What happens when two agents (or a human and an agent) investigate the same incident simultaneously? Do they share investigation context? Merge evidence sets? This is a real operational scenario.
- **Field lists are incomplete.** "Each catalog record includes at least: object key, signal type, source locator, time coverage, correlation keys, resolution, and freshness." What is "object key"? A service name? A resource tuple? A custom identifier? "Source locator" — an index name? A Data Prepper pipeline ID? These terms need definitions or examples.
- **No retention/lifecycle policy.** Investigation state accumulates. How long are investigation contexts kept? Are concluded investigations archived? What's the storage overhead estimate?

### Section 6.3: Query/Execution

**What works:** The 5 primitives (discover/narrow/pivot/compare/continue) map well to how investigators actually think. The "Why this solves the problem" paragraph correctly links back to Section 2.2. The non-goals correctly avoid prescribing syntax.

**Issues:**
- **Primitives are named but not specified.** Each gets 1-2 sentences. Critical questions for each:
  - `discover`: Is this a PPL command? REST API? MCP tool? What's the input (service name? time range? resource tuple?)? What's the output schema?
  - `narrow`: "Uses investigation summaries for early narrowing" — how? A filtered query on summary indexes? A sketch merge? What does the output look like?
  - `pivot`: "Moves across signals without losing investigation context" — what is the context contract? How is it passed between queries? Is it a session ID? An index document?
  - `compare`: "Compares suspect candidates" — what's the comparison function? Time-window diff? Set intersection? Statistical test?
  - `continue`: "Allows investigation to continue incrementally" — this implies stateful sessions. Where is state stored? How is it restored? This is the least specified primitive and arguably the hardest to implement.
- **No PPL examples.** The RFC says "PPL, DSL, or API can all carry these primitives" but shows zero examples. The companion design (file #4, §5.2) has excellent PPL examples for 4 of 5 primitives. The RFC should include at least pseudocode.
- **No mapping to existing OpenSearch capabilities.** How do these primitives relate to existing PPL commands (`stats`, `dedup`, `rare`, `patterns`, `anomaly detection`)? Are they new commands or compositions of existing ones?

### Section 6.4: Agent Integration

**What works:** The 4 interfaces are logically sound. The "shared model for human and agent" principle (interface #4) is the right architectural choice — it avoids the trap of building a separate agent-only system. The "Why this solves the problem" section correctly links to Sections 2.1 and 2.3.

**Issues:**
- **Ignores existing MCP tool surface.** Ref12 shows OpenSearch already exposes 30+ tools via MCP server at `/_plugins/_ml/mcp`, including SearchAlertsTool, SearchAnomalyDetectorsTool, SearchAnomalyResultsTool, PPLTool. The RFC should specify how investigation objects extend this existing surface — new tool registrations? New tool types? The companion design (file #4, §6) defines 4 concrete MCP tools with input/output schemas. The RFC has none.
- **"Investigation object API" is undefined.** "Phase 1 includes at least: investigation context, suspect set, evidence set, and conclusion state" — as REST endpoints? OpenSearch plugin APIs? MCP tools? What are the CRUD operations? What are the request/response schemas?
- **"Machine-readable evidence contract" needs a schema.** "Each evidence item includes at least: evidence type, related object, supporting signals, confidence/completeness, and conclusion impact" — this is a field list, not a contract. Show a JSON example.
- **Agent type compatibility unstated.** Ref12 specifies that MCP tools only work with conversational and plan-execute-reflect agents, not flow agents. The RFC should state which agent types can consume investigation objects.

### Section 6.5: Governance

**What works:** The 4 boundaries (evidence, conclusion, action, audit) are the right decomposition. Making `inconclusive` a first-class outcome is a genuinely good design choice. The audit boundary ("what was checked, why scope was narrowed, why a suspect was retained or excluded") is the most operationally valuable boundary.

**Issues:**
- **Most abstract section in the RFC.** Every other section at least names concrete constructs. This section has no data structures, no APIs, no index fields, no examples. How is an evidence boundary *implemented*? Is it a field on the evidence document? A separate index? A validation rule?
- **Evidence type taxonomy is incomplete.** "Distinguish raw signal, derived evidence, supporting evidence, and insufficient evidence" — what about contradictory evidence? Stale evidence? Evidence from untrusted sources? The taxonomy needs more thought or an explicit "Phase 1 supports only these 4 types" scoping.
- **Action boundary is the most consequential and least specified.** "Distinguish which results are only suitable for analysis and which may enter alert enrichment, routing, recommendation, or remediation workflows" — this is where safety-critical decisions happen. Who sets these boundaries? Are they configurable? What's the default? This needs much more detail.
- **No integration with OpenSearch security plugin.** Governance boundaries imply access control (who can change a conclusion state? who can authorize action?). OpenSearch has a security plugin with roles and permissions. No mention of how governance maps to it.

### Section 7: Problem-Solution Mapping

**What works:** The table is clean and traceable. Every problem from Section 2 maps to specific solution components. The caveat about Section 2.4 ("not fully solved in phase 1") is honest and appropriate.

**Issues:**
- **The "How it resolves" column restates the solution, not the mechanism.** E.g., for 2.2: "Summaries provide early narrowing input; discover/narrow/pivot/compare/continue support continuous narrowing." This says *what* solves it, not *how*. A more useful column would describe the concrete mechanism.
- **No gap analysis.** The table claims full coverage of 2.1–2.3. But are there sub-problems within each that remain unaddressed? E.g., 2.1 mentions "which service, tenant, or version to focus on" — does the signal catalog actually support tenant-level discovery?

### Section 8: Rollout

**What works:** P0/P1/P2 prioritization is logical. The reasoning ("P0 establishes the minimum closed loop") is sound. Placing agent integration APIs in P1 (not P0) is correct — the investigation model must exist before it can be exposed.

**Issues:**
- **P0 scope is very large.** Signal catalog + investigation summaries + 5 query primitives + investigation context + evidence/conclusion state + governance boundaries — this is essentially the entire RFC minus agent APIs. Is this achievable in a single phase? No timeline or effort estimate is given. The companion design estimates 10-14 weeks for DataSketches Phase 1 alone.
- **"Investigation summaries" in P0 includes DataSketches.** Section 6.1 defines summaries as "derived metrics/histograms and mergeable sketches." Derived metrics already exist (ref09). Sketches require new infrastructure. Should sketches be P0 or P1?
- **No success criteria per phase.** What does "P0 complete" look like? A working demo? Passing integration tests? A specific set of PPL queries that work end-to-end?
- **No dependency ordering within P0.** Signal catalog must exist before `discover` works. Investigation context must exist before `continue` works. The internal dependencies aren't mapped.

### Section 9: Non-goals

**What works:** All 5 non-goals are appropriate. "Not an agent-only observability system" is the most important one and correctly stated.

**Issues:**
- **Missing non-goal: UI redesign.** The RFC repeatedly says "UI remains important" but never scopes what UI work is in/out. Is redesigning Trace Analytics UI a non-goal? Is a new "Investigation" dashboard a non-goal?
- **Missing non-goal: real-time streaming investigation.** The RFC's model is batch/query-oriented. Is real-time investigation (e.g., live-updating investigation state as new telemetry arrives) explicitly out of scope?
- **"Rewrite the underlying storage engine in phase 1" implies it might happen later.** Is that intentional? If so, what would trigger it?

### Section 10: FAQ

**What works:** Q1 ("Is this problem only introduced by agents?") is the right first question and the answer is correct. Q2 ("Why not add mirror fields?") correctly defends the OTel reuse posture. Q3 ("Why DataSketches?") correctly positions sketches as investigation primitives, not query optimization.

**Issues:**
- **Missing FAQs:**
  - "How does this relate to OpenSearch Application Analytics?" — Application Analytics already groups logs/traces/metrics by application. Why isn't that sufficient?
  - "How does this relate to OpenSearch Notebooks?" — Notebooks already combine visualizations + code. Why aren't they investigation containers?
  - "What's the performance overhead?" — Adding signal catalog population, sketch computation, and investigation state persistence all have cost.
  - "How do existing users migrate?" — Backward compatibility story.
  - "Why not extend Alerting monitors as investigation entry points?" — Alerting already detects conditions; the gap is what happens after detection.
  - "What are the error bounds of sketch-based narrowing?" — Trustworthiness for incident response.

---

## Cross-Cutting Analysis

### Citation Accuracy

| Statistic | Source Claimed | Verdict | Notes |
|-----------|---------------|---------|-------|
| "88% use two or more monitoring tools" | New Relic 2024 | **UNVERIFIABLE** | Not in ref03. Closest: 45% use 5+ tools |
| "34% identify too many tools and data silos" | New Relic 2024 | **UNVERIFIABLE** | Not in ref03. The 34% in NR refers to DORA metrics reducing downtime |
| "average of 8 observability technologies" | Grafana 2025 | **VERIFIED** | ref04 confirms (down from 9 in 2024) |
| "average of 16 data sources" | Grafana 2025 | **VERIFIED** | ref04 confirms |
| "17% of total compute infrastructure spend" | Grafana 2025 | **VERIFIED** | ref04: mean 17%, median/mode 10% |
| "10% is the most common response" | Grafana 2025 | **VERIFIED** | ref04 confirms as mode |
| "74% consider cost a major factor" | "Grafana follow-up article" | **MISLEADING** | Same Grafana 2025 survey (ref04), not a separate article |
| Datadog Bits AI hypothesis-evidence loop | Datadog docs | **VERIFIED** | ref05 confirms continuous loop with explicit inconclusiveness |
| "OTel elevating AI agent observability in 2025" | OTel | **OVERSTATED** | ref02: GenAI is one emerging row in semantic conventions, not a major initiative |
| LangChain/LangSmith agent observability | Uncited | **UNCITED** | No reference entry provided |
| Data Prepper derives metrics from traces | OpenSearch docs | **VERIFIED** | ref09 confirms aggregate processor with histogram action |

### Internal Consistency

- **Sections 1→2 redundancy.** The problem is stated in the abstract, restated in Section 1, then re-decomposed in Section 2 with a preamble that restates Section 1. Three layers of framing before any solution.
- **Section 3 forward-references Section 6.** The module matrix uses layer names (Ingestion, Storage, etc.) that aren't defined until Section 6. Should be reordered or the matrix should define its terms.
- **Section 6.1 claims "Phase 1 supports only two types" of summaries** but Section 8 puts all summaries in P0 without distinguishing derived metrics (existing) from sketches (new).
- **Section 7 claims 2.1–2.3 are solved** but the solution sections (6.1–6.5) lack enough specification to verify this claim.
- **No contradictions found.** The RFC is internally consistent in its claims, just underspecified.

### Completeness — What's Missing

1. **Index schemas** for all 4 storage objects (signal catalog, summaries, context, evidence)
2. **API specifications** — REST endpoints, request/response schemas
3. **PPL examples** for each of the 5 query primitives
4. **State machine** for investigation lifecycle (transitions, triggers, concurrency)
5. **Security model** — who can read/write investigation objects, integration with OpenSearch security plugin
6. **Backward compatibility** — migration path for existing observability users
7. **Performance analysis** — overhead of catalog population, sketch computation, state persistence
8. **Failure modes** — stale catalog, corrupted state, sketch merge failures, degradation strategy
9. **Alternatives considered** — why not extend Notebooks, Application Analytics, Alerting
10. **End-to-end walkthrough** — one scenario traced through all 5 layers with concrete queries
11. **Error bounds** for sketch-based primitives (HLL ±1.3%, KLL ±1.33% — from companion design)
12. **Competitive analysis** — how this compares to Datadog Bits AI, Grafana Incident, PagerDuty AIOps

### Audience Fit

- **For an OpenSearch contributor:** Insufficient to implement. They'd know *what* to build but would need to make dozens of design decisions the RFC doesn't address.
- **For a product manager:** The problem statement is compelling. The solution is too abstract to evaluate feasibility or scope.
- **For an external reviewer:** The RFC reads well as a position paper. It does not read as an engineering RFC.
- **Recommendation:** Split into (a) a vision/position document (Sections 1-5, trimmed) and (b) a technical design document (Sections 6-8, expanded with schemas, APIs, examples).

### Comparison with Companion DataSketches Design

The companion design (file #4) is dramatically more concrete than the RFC:

| Aspect | RFC | Companion Design |
|--------|-----|-----------------|
| Index mappings | None | Full JSON mapping for sketch storage |
| PPL functions | "PPL can carry these primitives" | 7 named functions with types and examples |
| MCP tools | "Expose via MCP" | 4 tools with input/output schemas |
| Pipeline config | "Can be constructed in the pipeline" | Full Data Prepper YAML |
| Walkthrough | None | 4-step p99 spike investigation with queries |
| Timeline | None | 10-14 weeks Phase 1, 24-30 weeks total |

The RFC should either incorporate the companion design's level of detail for all subsystems, or explicitly reference it as the detailed design for the sketches subsystem and produce equivalent companion designs for signal catalog, investigation state, and agent integration.

---

## Prioritized Recommendations

### Must Fix (before RFC is implementable)

1. **Fix/remove unverifiable statistics.** Replace "88%" and "34%" with verified New Relic figures (45% use 5+ tools, 41% plan to consolidate) or remove. Add citation for LangChain/LangSmith claim.
2. **Define signal catalog index schema.** Show the mapping, the Data Prepper processor, a sample document, and the population/staleness mechanism. This is the foundation.
3. **Specify query primitives concretely.** For each of discover/narrow/pivot/compare/continue: input parameters, execution semantics, output schema, one PPL example.
4. **Define investigation state machine.** Valid transitions between the 5 states, triggers, concurrency model, index mapping.
5. **Add end-to-end walkthrough.** One realistic scenario (e.g., p99 spike) traced through all 5 layers with concrete API calls and queries.

### Should Fix (for a strong RFC)

6. **Acknowledge existing OpenSearch capabilities more fully.** Application Analytics, Anomaly Detection, Notebooks, 30+ MCP tools, OpenSearch Assistant — explain why they're insufficient rather than omitting them.
7. **Scope P0 more tightly.** Either reduce P0 scope or add internal dependency ordering and effort estimates. Current P0 is the entire RFC minus agent APIs.
8. **Add Alternatives Considered section.** Why not extend Notebooks as investigation containers? Why not extend Alerting as entry points? Why not extend Application Analytics as the grouping mechanism?
9. **Cut problem statement by 40%.** State the problem once with evidence in Section 1. Remove the restated preambles in Sections 2 and 4.
10. **Add security and failure mode sections.** Even brief ones — who can write investigation state? What happens when the signal catalog is stale?

### Nice to Have

11. **Add anti-principles** to Section 5 (what the RFC explicitly does not optimize for).
12. **Add missing FAQs** (Application Analytics, Notebooks, performance overhead, migration, error bounds).
13. **Incorporate companion design references.** Either inline the DataSketches detail or produce equivalent companion designs for other subsystems.

---

## Scorecard

| Criterion | Score | Notes |
|-----------|-------|-------|
| **Clarity** | Partial | Problem framing is excellent. Solution sections name constructs without specifying them. |
| **Verification** | Fail | No acceptance criteria, no testable specs, no example queries, 2 unverifiable stats. |
| **Context Completeness** | Partial | Strong external references. Incomplete internal OpenSearch capability inventory. No schemas/APIs. |
| **Big Picture** | Pass | Clear purpose, logical flow, honest about Phase 1 limitations, good problem-to-solution traceability. |

**Overall: ⭐⭐⭐ — The RFC correctly identifies a real gap and proposes the right structural response. But it stops at naming constructs without specifying them. An implementer would need to make dozens of unguided design decisions. The companion DataSketches design proves that concrete specification is possible — the RFC needs that level of detail for all subsystems.**
