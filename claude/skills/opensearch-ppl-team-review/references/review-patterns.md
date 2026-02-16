# PPL Review Patterns

Patterns to produce precise, high-signal findings in OpenSearch PPL reviews.

## High-Value Finding Patterns

1. PPL command behavior changed without corresponding test updates
2. Behavior changed without integ-test or yamlRestTest coverage
3. Linked issue has explicit PPL examples, but one or more examples have no
   direct test coverage
4. Snapshot/expected output changed without semantic explanation
5. Cleanup path moved or removed in pagination/PIT logic
6. Pushdown or rule-order change can alter plan/results for PPL queries in
   edge cases (nested fields, multi-valued, null-heavy)
7. Exception conversion loses root cause or actionable context
8. Permission-sensitive path changed without integration coverage
9. New branching/flags make PPL command control flow harder to validate
10. User-facing PPL syntax or behavior changed without docs/doctest updates
11. Join/lookup/subquery scope change can leak or shadow field names
12. Aggregation pushdown in stats/rare/top alters null-handling semantics
13. Parse/patterns/grok regex change can silently change extraction results
14. Fillnull/flatten/expand changes affect downstream command assumptions

## Team-Specific Patterns

### ppl-logic teammate should watch for

- Grammar ambiguity introduced by new syntax rules
- Visitor not handling a new AST node type (ClassCastException risk)
- Analyzer allowing type mismatch that will fail at runtime
- Plan shape change breaking existing Calcite rule assumptions
- Null semantics inconsistency across PPL command boundaries

### test-integration teammate should watch for

- Test names that do not match actual test behavior
- Snapshot updates that silently accept regression
- Missing negative-path tests for new error conditions
- Docs showing old syntax/output after behavior change
- yamlRestTest missing for new PPL command features

### security-perf teammate should watch for

- PIT handle leak on exception path
- Field-level security bypassed by new projection logic
- Unbounded materialization in join/subquery execution
- Resource cleanup skipped when cursor fetch fails mid-stream
- Permission check removed or weakened in code reorganization

## Comment Framing

- Lead with impact, not implementation detail
- Keep tone concise and engineer-to-engineer (not formal)
- Include one concrete next step
- Keep each finding focused on one risk
- Use `question` severity only for genuine uncertainty

## Example Phrasing

- "This can leak PIT handles when the fetch path throws before close."
- "Rule ordering may skip projection trimming for nested fields in PPL join."
- "Add cleanup in the exception branch and cover with an integration test."
- "The stats pushdown drops null groups; add a test with null-only partition."
- "Parse pattern changed but existing tests still pass with old regex; add
  a case that would catch the semantic difference."

## Anti-Patterns to Avoid

1. Vague comments without path/line references
2. Multiple unrelated concerns in one finding
3. Style-only feedback when major risk remains unresolved
4. Asking for refactors without explaining risk or benefit
5. Reporting merge-conflict status as code-quality finding
6. Duplicating findings already covered by another teammate
7. Speculating about issues without inspecting the actual code in the worktree
