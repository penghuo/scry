# RFC Review v2: OpenSearch Agent Observability Investigation Framework v0.1

**Reviewer:** Momus (refreshed)
**Rating:** ⭐⭐⭐⭐ (OKAY — Good with Minor Issues)
**Previous Rating:** ⭐⭐⭐ (v1)
**Upgrade Reason:** DataSketches feasibility proven; companion design resolves the largest technical gap.

---

## VERDICT: OKAY ⭐⭐⭐⭐

### Summary

The RFC's conceptual framework is strong and now has concrete engineering backing for its most ambitious claim. The DataSketches companion design (`oracle-datasketches-design.md`) proves feasibility with specific extension points, index mappings, PPL functions, and a phased timeline. However, the RFC itself hasn't incorporated these findings — creating a documentation gap where the vision document and the engineering design live in separate artifacts. Remaining issues: two unverifiable stats, no signal catalog schema, query primitives still underspecified in the RFC text, no end-to-end walkthrough in the RFC.

---

## 1. STRENGTHS (Updated)

- **DataSketches feasibility is now proven, not asserted.** Three key evidence points:
  1. OpenSearch's existing `cardinality` agg uses HLL++ internally (RFC line 138; architecture doc §1) — the shard-then-reduce sketch pattern already works.
  2. Druid's dual Build/Merge aggregator pattern (`librarian-datasketches-integrations.md` §1) provides a proven reference architecture.
  3. Clean extension points identified: Data Prepper `AggregateAction` for ingestion, `SearchPlugin.getAggregations()` SPI for query (`librarian-opensearch-architecture.md` §5).
- **Sketch→primitive mapping validates the RFC's investigation model.** HLL→discover, KLL→narrow, Theta→pivot/compare (`librarian-datasketches-observability.md` "Key Insight"). This isn't retrofitted — the primitives genuinely map 1:1 to sketch operations.
- **PPL function design is concrete.** `sketch_count_distinct`, `sketch_percentile`, `sketch_diff`, `sketch_intersect`, `sketch_estimate` (`oracle-datasketches-design.md` §5) — these make the query primitives implementable.
- **End-to-end walkthrough exists** in the companion design (§7): alert → discover(HLL) → narrow(KLL) → pivot(Theta AnotB) → compare(Theta intersection) → rollback decision. This is exactly what the RFC needs.
- Original strengths maintained: good problem framing, correct OTel reuse posture, governance layer with explicit `inconclusive` state.

---

## 2. STRUCTURAL ISSUES (Updated)

**S1. [MAINTAINED] Problem statement is ~60% of the document.** Sections 1-4 are ~2,200 words before any solution. Still restated 3-4 times. Compress to one section.

**S2. [MAINTAINED] Solution sections are symmetric but shallow.** Goal/Proposed/Non-goals template masks the lack of implementable detail.

**S3. [MAINTAINED] No end-to-end walkthrough in the RFC.** The companion design (§7) has an excellent one. The RFC itself still doesn't.

**S4. [NEW] RFC-to-design-doc gap.** The RFC claims DataSketches as Phase 1 (line 138, 161) but contains zero implementation detail. The companion design (`oracle-datasketches-design.md`) has index mappings, PPL functions, pipeline config, MCP tools, and a 10-14 week estimate. This creates two problems: (a) the RFC reads as hand-waving to anyone who hasn't seen the companion doc, (b) the companion doc specifies things (PPL functions, MCP tool surface) that should be in the RFC's query/agent sections.

---

## 3. TECHNICAL GAPS (Updated)

**T1. [MAINTAINED] Signal catalog is undefined.** RFC line 158 lists fields ("object key, signal type, source locator...") but no index schema, no population mechanism, no Data Prepper processor config. Still a concept, not a design.

**T2. [MAINTAINED in RFC, PARTIALLY RESOLVED in companion] Query primitives underspecified.** The RFC's 5 primitives (discover/narrow/pivot/compare/continue) get 1-2 sentences each. The companion design maps 4 of 5 to concrete PPL functions and MCP tools — but `continue` (stateful investigation resumption) remains unspecified anywhere.

**T3. [MAINTAINED] Investigation state machine undefined.** Five states listed (open/narrowed/suspected/inconclusive/concluded) with no transitions, no concurrency model, no index mapping, no garbage collection.

**T4. [UPGRADED: unrealistic → feasible with concrete design]** DataSketches integration now has:
- Specific sketch types mapped to primitives (HLL, KLL, Theta, FreqItems)
- Data Prepper `sketch_aggregate` AggregateAction with pipeline YAML config
- OpenSearch `sketch_build`/`sketch_merge` dual aggregator via `SearchPlugin.getAggregations()` SPI
- Index mapping with binary fields + doc_values for sketch storage
- 7 PPL functions with input/output types
- 4 MCP tools with input/output schemas
- Phased timeline: Phase 1 (HLL+KLL) = 10-14 weeks
- Precedent: 5 major systems (Druid, Spark, BigQuery, Redshift, PostgreSQL) all follow the same BUILD→MERGE→ESTIMATE lifecycle

**The original "unrealistic" assessment was wrong.** The author was right to push back — the engineering effort is well-scoped and follows established patterns. The existing `cardinality` aggregation is proof that OpenSearch already does sketch-based aggregation internally.

**T5. [MAINTAINED] No PPL integration design in the RFC.** The companion design (§5) has this. The RFC doesn't.

**T6. [MAINTAINED in RFC, RESOLVED in companion] MCP tool surface unspecified in RFC.** The companion design (§6) defines 4 tools with schemas. The RFC still says only "expose via MCP."

---

## 4. EVIDENCE/CITATION ISSUES (Maintained)

**E1. [STILL UNVERIFIABLE]** "88% of respondents use two or more monitoring tools" (RFC line 23, attributed to New Relic 2024). Not found in cited source.

**E2. [STILL UNVERIFIABLE]** "34% identify too many tools and data silos" (RFC line 23, attributed to New Relic 2024). Not found in cited source.

**E3-E6.** Same as v1 review — Grafana stats verified, Datadog characterization accurate, OTel maturity overstated.

---

## 5. MISSING CONSIDERATIONS (Updated)

**M1-M5 maintained:** No index mappings (except in companion), no performance/scale analysis, no backward compatibility, no security model, no failure modes — all still absent from the RFC.

**M6. [NEW] No sketch error bound discussion in RFC.** The companion design and research docs quantify error bounds (HLL ±1.3% RSE at lgK=14, KLL ±1.33% rank error at K=200). The RFC should state acceptable error bounds for investigation primitives — this affects whether sketch-based narrowing is trustworthy for incident response.

---

## 6. RECOMMENDATIONS FOR v0.2 (Re-prioritized)

1. **[P0] Incorporate companion design into RFC.** Move the PPL functions (§5), MCP tools (§6), index mapping (§3), and walkthrough (§7) from `oracle-datasketches-design.md` into the RFC's query/agent/storage sections. The RFC should be self-contained.

2. **[P0] Define signal catalog schema.** Show the index mapping, the Data Prepper processor, and a sample document. This is the other P0 foundation alongside sketches.

3. **[P0] Fix or remove unverifiable statistics (88%, 34%).** Replace with verified New Relic stats or remove.

4. **[P1] Specify `continue` primitive.** The only investigation primitive with no concrete design anywhere. How is investigation state persisted and resumed?

5. **[P1] Define investigation state machine.** Valid transitions, triggers, index mapping, concurrency.

6. **[P1] Add error bound requirements.** State acceptable sketch accuracy for each primitive. Cite the research: HLL ±1.3%, KLL ±1.33% rank error.

7. **[P2] Cut problem statement by 50%.** State once, move on.

8. **[P2] Add "Alternatives Considered" section.** Why not extend Notebooks, Application Analytics, or Alerting?

---

## Criteria Scorecard

| Criterion | v1 | v2 | Notes |
|-----------|----|----|-------|
| Clarity | Partial | Partial | Solution sections still shallow in RFC; companion design fills gaps but isn't integrated |
| Verification | Fail | Partial | Companion design has concrete PPL examples and MCP schemas; RFC itself still lacks testable specs |
| Context Completeness | Partial | Pass | Research docs provide full architectural context, extension points, and cross-system precedent |
| Big Picture | Pass | Pass | Purpose clear, problem-to-solution traceability maintained, sketch→primitive mapping strengthens narrative |
