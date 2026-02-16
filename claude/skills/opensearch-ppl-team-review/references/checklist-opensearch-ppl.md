# OpenSearch PPL Review Checklist

Subsystem-specific checklists for the deep review pass. Each teammate reads
the sections relevant to their role.

## PPL Logic and Semantics

_Primary owner: ppl-logic teammate_

### PPL Command Coverage

Verify correctness for any PPL command touched by the PR:

- **search/source**: index resolution, source filtering, metadata field access
- **where**: filter expression evaluation, type coercion, null propagation
- **fields**: projection correctness, include/exclude mode, nested field paths
- **stats**: aggregation functions, grouping, span, null handling in aggregates
- **dedup**: deduplication semantics, consecutive mode, keepempty behavior
- **sort**: sort order, null ordering, multi-key sort stability
- **eval**: expression evaluation, new field creation, overwrites
- **head/tail**: limit semantics, offset handling
- **rare/top**: frequency computation, grouping, tie-breaking
- **parse/patterns/grok**: regex extraction, field naming, partial match behavior
- **rename**: field renaming, conflict resolution, downstream references
- **join/lookup**: join type semantics, field qualification, null in join keys
- **subquery**: scope isolation, correlated vs uncorrelated, result materialization
- **correlation**: field pairing, time-based correlation window handling
- **fillnull**: replacement value semantics, per-field vs global fill
- **flatten/expand**: nested structure handling, array explosion, type preservation
- **trendline**: window function semantics, boundary conditions, null in series
- **describe**: metadata retrieval, schema accuracy
- **AD/ML**: algorithm parameter validation, result schema, error propagation

### Parser and AST

- Grammar changes produce correct AST for new/modified syntax
- Visitor patterns handle new node types consistently
- Error messages for malformed PPL are clear and actionable
- Backward compatibility: existing valid PPL still parses correctly

### Analyzer and Type System

- Type resolution correct for new/modified expressions
- Field binding resolves correctly across subqueries and join scopes
- Scope handling: field visibility across piped commands is consistent
- Alias resolution does not shadow unexpectedly

### Planner and Calcite Rules

- Plan shape invariants preserved after rule changes
- Rule ordering side effects considered (rule A before B vs B before A)
- Pushdown correctness: pushed predicates produce identical results
- Projection trimming does not drop required fields
- Aggregation pushdown preserves grouping semantics
- Multi-valued and nested fields produce expected query plans

### Null and Edge Cases

- Null propagation follows three-valued logic consistently
- Empty result sets handled without exceptions
- Boundary values (empty string, zero, max int, deeply nested) tested
- Multi-valued fields: UNNEST/flatten semantics correct

## Execution and Lifecycle

_Primary owner: security-perf teammate_

- Pagination/PIT create and cleanup paths are paired correctly
- Cursor lifecycle and fetch-size behavior consistent across success and failure
- Exception flow preserves root cause and avoids swallowing actionable errors
- Resource cleanup happens on all paths (normal, timeout, exception)
- Streaming assumptions remain valid where applicable

## Security and Permissions

_Primary owner: security-perf teammate_

- Permission checks not bypassed or weakened
- Cross-index access respects tenant isolation
- Field-level security applied correctly in projection
- Document-level security filters not dropped during pushdown
- Request objects initialized before use (builders, explain state, context fields)
- API usage compatible with expected OpenSearch versions

## Performance and Stability

_Primary owner: security-perf teammate_

- Added loops, sorting, or materialization do not create avoidable hot-path cost
- Object allocations and intermediate structures bounded in hot paths
- Backpressure and streaming assumptions still valid
- Query size or limit changes are intentional and justified
- No unbounded data materialization in memory

## Tests and Snapshots

_Primary owner: test-integration teammate_

- Behavior changes include at least one focused unit or integration test
- Behavior-changing PRs should include integ-test or yamlRestTest coverage
- Snapshot/expected output updates reflect intentional behavior change
- Negative-path tests exist for fragile logic (permissions, nested fields,
  pagination cleanup, malformed PPL input)
- Linked issue examples each have test coverage or clear rationale
- If tests not added, rationale is explicit and credible

## Docs and Doctest

_Primary owner: test-integration teammate_

- User-visible syntax/behavior changes update docs or doctest coverage
- PPL command documentation matches actual behavior after the PR
- Examples in docs are runnable and produce shown output
- Error examples match actual API response format
- Related command cross-references are accurate
- Any docs omission explicitly justified in review output

## Approval Gate

_All reviewers contribute; lead adjudicates_

- No unresolved blocker or major findings
- Test evidence present or risk explicitly accepted
- Missing both integ-test and yamlRestTest for behavior-changing PRs is an
  approval gap (at least major; blocker for high-risk paths)
- Snapshot updates are intentional
- User-facing changes include docs/doctest updates or explicit rationale
- Follow-up questions tracked when assumptions remain
