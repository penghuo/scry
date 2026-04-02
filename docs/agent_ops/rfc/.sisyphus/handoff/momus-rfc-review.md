# RFC Review: OpenSearch Agent Observability Investigation Framework v0.1

**Reviewer:** Momus  
**Rating:** ⭐⭐⭐ (OKAY — Workable with Risk)

---

## VERDICT: OKAY ⭐⭐⭐

### Summary

Strong conceptual framing of the investigation-as-first-class-object idea, but the RFC is heavy on problem articulation and light on implementable specification. The 5 query primitives, signal catalog schema, and storage objects lack enough concrete detail to build against. Two cited statistics cannot be verified against their claimed sources.

---

## 1. STRENGTHS

- Problem statement is well-argued and grounded in real operational pain. The framing of "capabilities exist but aren't organized into an investigation process" is precise.
- Correct reuse posture: builds on OTel semantics and existing OpenSearch stack (Data Prepper, PPL, MCP) rather than reinventing.
- The module matrix (Section 3) mapping problems to system layers is useful for scoping work.
- Governance layer with explicit `inconclusive` state is a genuinely good design choice, correctly citing Datadog's pattern.
- Section 7 traceability table linking problems to solutions is clean.

---

## 2. STRUCTURAL ISSUES

**S1. Problem statement is ~60% of the document.** Sections 1-4 are ~2,200 words of problem framing before any solution appears. For an RFC targeting implementers, this ratio is inverted. The problem is restated 3-4 times with slight variation (Abstract, Section 1 para 1, Section 2 intro, Section 4). Compress to one tight section.

**S2. Solution sections are symmetric but shallow.** Sections 6.1-6.5 each follow the same Goal/Proposed/Non-goals template, which reads well but masks the fact that none of them specify enough to implement. Every section stops at "what" without reaching "how."

**S3. No architecture diagram or data flow.** For a system that spans ingestion → storage → query → agent → governance, there is no end-to-end flow showing how an investigation actually moves through these layers. A concrete walkthrough (e.g., "alert fires → signal catalog lookup → narrow via summary → pivot to traces → conclude") would expose gaps the prose currently hides.

---

## 3. TECHNICAL GAPS

**T1. Signal catalog is undefined.** The RFC says each record includes "object key, signal type, source locator, time coverage, correlation keys, resolution, and freshness" but never specifies: What is the index schema? How is it populated — Data Prepper processor? Background job? What is the "object key" — service name? Resource tuple? How does it handle multi-tenant or multi-cluster? Without this, "signal catalog" is a concept, not a design.

**T2. Five query primitives are not specified enough to implement.** `discover`, `narrow`, `pivot`, `compare`, `continue` — each gets 1-2 sentences. Critical questions unanswered:
- Is `discover` a new PPL command? A REST API? An MCP tool?
- What does `narrow` actually execute — a sketch query? A filtered aggregation?
- How does `pivot` maintain context across signal types? What's the state contract?
- What does `compare` compare — two time windows? Two services? What's the output schema?
- How does `continue` persist and restore state — OpenSearch index? In-memory session?

**T3. Investigation state storage is hand-waved.** Five states (`open`, `narrowed`, `suspected`, `inconclusive`, `concluded`) are listed but: What are the valid transitions? Who/what triggers transitions? What's the index mapping? How is concurrent access handled (two agents investigating the same incident)? How is state garbage-collected?

**T4. DataSketches integration is asserted but not designed.** The RFC says "DataSketches provide mergeable summaries suitable for layered aggregation" but doesn't specify: Which sketch types (HLL, KLL, Theta, CPC)? Where do they run — Data Prepper? OpenSearch plugin? How are they queried via PPL? OpenSearch doesn't natively support DataSketches today — this is a significant engineering effort presented as a Phase 1 item.

**T5. No PPL integration design.** The RFC repeatedly references PPL as the natural carrier for investigation primitives but never shows what investigation-aware PPL would look like. Even pseudocode would help: `source = signal_catalog | where object = "checkout-service" | discover` — is that the model?

**T6. MCP tool surface is unspecified.** Section 6.4 says investigation objects should be exposed via MCP but doesn't define tool names, input/output schemas, or how they map to OpenSearch's existing MCP server pattern (which already exposes SearchIndex, PPL, etc.).

---

## 4. EVIDENCE/CITATION ISSUES

**E1. [UNVERIFIABLE] "88% of respondents use two or more monitoring tools" (attributed to New Relic 2024).** The New Relic 2024 reference summary contains no such statistic. The closest is "45% of organizations use 5+ tools." The 88% figure cannot be verified against the cited source.

**E2. [UNVERIFIABLE] "34% identify too many tools and data silos as a major obstacle" (attributed to New Relic 2024).** Not found in the reference summary. The 34% in New Relic refers to DORA metrics as a practice reducing downtime — completely different context.

**E3. [MISLEADING] "Grafana's follow-up cost management article also states that 74%..."** The 74% comes from the Grafana 2025 survey itself, not a separate "follow-up cost management article." This makes it sound like independent corroboration when it's the same source.

**E4. [ACCURATE] Grafana stats (8 technologies, 16 data sources, 17% spend, 10% mode) — all verified.**

**E5. [ACCURATE] Datadog Bits AI characterization — the hypothesis-evidence-conclusion loop and explicit inconclusiveness are correctly represented.**

**E6. [VAGUE] "OTel elevating AI agent observability as a distinct topic in 2025" — the OTel semantic conventions reference shows Generative AI as an emerging category but the RFC overstates the maturity. It's listed as one row in a convention table, not a major initiative with published specs.**

---

## 5. MISSING CONSIDERATIONS

**M1. No concrete mapping to OpenSearch indexes.** Which new indexes does this create? What are their mappings? How do they relate to existing `otel-v1-apm-span`, `otel-v1-apm-service-map`? This is an OpenSearch RFC — index design is the most fundamental decision.

**M2. No performance or scale analysis.** Signal catalog lookups, sketch merges, and state persistence all have cost. At what scale does this work? What's the overhead on ingestion latency? No sizing estimates.

**M3. No backward compatibility story.** How do existing OpenSearch observability users adopt this? Is the signal catalog auto-populated from existing indexes? Do existing Data Prepper pipelines need modification?

**M4. No security model.** Investigation state contains sensitive operational data. Who can read/write investigation objects? How does this integrate with OpenSearch's security plugin?

**M5. No failure modes.** What happens when signal catalog is stale? When sketch merge fails? When investigation state is corrupted? No degradation strategy.

**M6. No comparison with alternatives.** The RFC doesn't discuss why this approach vs. extending existing OpenSearch features (e.g., Notebooks as investigation containers, Alerting monitors as entry points, Application Analytics as the grouping mechanism).

---

## 6. SPECIFIC RECOMMENDATIONS (Priority Order)

1. **[P0] Define signal catalog index schema and population mechanism.** Show the mapping, show the Data Prepper processor config, show a sample document. This is the foundation everything else depends on.

2. **[P0] Specify query primitives as concrete PPL commands or REST APIs.** For each of the 5 primitives, provide: input parameters, execution semantics, output schema, and one worked example.

3. **[P0] Fix or remove unverifiable statistics (88%, 34%).** Either find the actual source or replace with the verified New Relic stats (45% use 5+ tools, 41% plan to consolidate).

4. **[P1] Add an end-to-end walkthrough.** Take one realistic scenario (e.g., "p99 latency spike on checkout-service") and trace it through all 5 layers with concrete API calls, index queries, and state transitions.

5. **[P1] Define investigation state machine.** Document valid state transitions, triggers, and the index mapping for investigation state documents.

6. **[P1] Scope DataSketches realistically.** Either move to P1/P2 or specify exactly which sketch types, where they execute, and what OpenSearch changes are required.

7. **[P2] Cut problem statement by 50%.** State the problem once with evidence, then move on. The current repetition dilutes impact.

8. **[P2] Add a "Alternatives Considered" section.** Explain why extending Notebooks, Application Analytics, or Alerting workflows wasn't sufficient.

---

## Criteria Scorecard

| Criterion | Score | Notes |
|-----------|-------|-------|
| Clarity | Partial | Good problem framing, but solution sections lack implementable detail |
| Verification | Fail | No acceptance criteria, no testable specifications, no example queries |
| Context Completeness | Partial | Good external references, but missing internal OpenSearch architecture mapping |
| Big Picture | Pass | Clear purpose, logical flow, good problem-to-solution traceability |
