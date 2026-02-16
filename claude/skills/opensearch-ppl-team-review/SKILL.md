---
name: opensearch-ppl-team-review
description: >
  Team-based PR/code review for opensearch-project/sql targeting PPL modules.
  Spawns an agent team with specialized reviewers (PPL logic, integration/test,
  security/performance) coordinated by a lead that synthesizes findings.
  Covers ppl, core, opensearch, calcite, integ-test, and docs modules.
  Excludes sql/legacy unless explicitly requested.
---

# OpenSearch PPL Team Review

## 1 Mission

You are the **team lead** for a multi-agent PR review of opensearch-project/sql,
focused on PPL (Piped Processing Language) changes. Your job is to orchestrate
a team of specialized reviewers, synthesize their findings, and produce a
single, high-signal review output.

Target modules: **ppl, core, opensearch, calcite, integ-test, docs**.
Ignore sql/legacy unless the user explicitly requests it.

## 2 Required Inputs

Before starting the review, collect:

- PR URL or number (opensearch-project/sql)
- PR description and linked issues
- Diff or changed file list (obtained via gh tooling)
- Test evidence: CI status, local test output, or explicit "not run"
- Logs, stack traces, or failing snapshots if available

## 3 Worktree Policy (MANDATORY)

Create a dedicated git worktree for the review. DO NOT review in the primary
working directory unless the user explicitly asks.

- Worktree path: `../sql-pr-<pr-number>-review`
- Branch name: `codex/review-pr-<pr-number>`
- Reuse existing worktrees; sync to current PR head.

### Worktree Setup Sequence

```
gh pr view <pr-url-or-number> --json number,baseRefName,headRefName,headRepositoryOwner
git fetch origin
git worktree add ../sql-pr-<pr-number>-review -b codex/review-pr-<pr-number> origin/<baseRefName>
cd ../sql-pr-<pr-number>-review
gh pr checkout <pr-url-or-number>
git status --short
```

## 4 Tooling Policy (MANDATORY)

Use GitHub tooling first (gh CLI or GitHub-native MCP tools).
DO NOT use generic web_fetch for PR files/diff/comments when gh is available.

Source order:

1. gh PR metadata, files, diff, checks, and comments
2. Local git inspection if needed
3. web_fetch only as last resort (state why gh unavailable; note reduced confidence)

### PR Intake Command Sequence

```
gh pr view <pr-url-or-number> --json number,title,body,author,baseRefName,headRefName,labels,changedFiles,additions,deletions,mergeable,url
gh pr view <pr-url-or-number> --json files
gh pr diff <pr-url-or-number>
gh pr checks <pr-url-or-number>
gh pr view <pr-url-or-number> --json comments
gh issue view <linked-issue> --json title,body,comments  # if linked issues exist
gh api repos/<owner>/<repo>/pulls/<pr-number>/comments    # if review comments exist
```

## 5 Agent Team Setup

After worktree setup and PR intake, create the review team.

### 5.1 Team Creation

Create a team named `ppl-review-pr-<pr-number>`.

### 5.2 Team Roles

Spawn **three** teammates. Each is a `general-purpose` agent type so they can
read files, run git/gh commands, and inspect the worktree.

| Teammate Name        | Focus Area                              |
| :------------------- | :-------------------------------------- |
| `ppl-logic`          | PPL semantics, parsing, planning, Calcite rules |
| `test-integration`   | Test coverage, integ-test, yamlRestTest, snapshots |
| `security-perf`      | Security, performance, resource lifecycle, OpenSearch integration |

### 5.3 Spawn Prompts

When spawning each teammate, include in their prompt:

1. The PR number, title, URL, and change summary you drafted during intake
2. The worktree path so they can read files locally
3. Their specific review focus (from the table above)
4. The severity rubric (section 7)
5. The finding format (section 11)
6. A pointer to read the relevant reference files under `references/`

Example spawn instruction for the lead to follow:

```
Spawn teammate "ppl-logic" (general-purpose) with prompt:

"You are a PPL logic reviewer for PR #<number> (<title>).
Worktree: ../sql-pr-<number>-review

Your focus: PPL command semantics, parsing pipeline, planner logic, and
Calcite rule correctness. Read references/checklist-opensearch-ppl.md
section 'PPL Logic and Semantics' for your checklist.

Review the diff, inspect changed files in the worktree, and produce findings
using this format:
  [severity N] path:line - Impact. Next step.

Severity levels: blocker, major, minor, nit, question.
Prefer fewer high-signal findings over a long list.
When done, send your findings back to me (the lead)."
```

Apply the same pattern for `test-integration` and `security-perf`, adjusting
the focus area and checklist section.

### 5.4 Task Creation

Create one task per teammate, plus a synthesis task for yourself:

1. **PPL logic review** - assigned to `ppl-logic`
2. **Test and integration review** - assigned to `test-integration`
3. **Security and performance review** - assigned to `security-perf`
4. **Synthesize findings and produce final review** - assigned to lead (yourself), blocked by tasks 1-3

### 5.5 Require Plan Approval for High-Risk PRs

If the PR is classified as high-risk during intake (behavior change in pushdown
rules, pagination/PIT lifecycle, permission paths, or query size limits),
spawn teammates with plan approval required. Review and approve each
teammate's plan before they proceed with the deep review.

### 5.6 Delegation

Use delegate mode thinking: focus on orchestration. Let teammates do the
deep file-level analysis. Your job is intake, coordination, synthesis, and
final output.

## 6 Review Workflow

### Step 1: Intake and Scope Lock (Lead)

- Read PR intent, issue context, and module ownership
- Classify change: bugfix, perf, refactor, feature, docs-only, backport
- Map changed files to impacted PPL runtime path (parser, analyzer, planner,
  executor, tests, docs)
- Extract acceptance examples/cases from linked issues into a checklist matrix
- Draft a short PR change summary (2-4 bullets + modules + behavior/test/docs impact)
- Share the summary with all teammates during spawn

### Step 2: Parallel Deep Review (Teammates)

Each teammate executes their specialized review concurrently:

**ppl-logic teammate:**
- PPL command semantics (search, stats, dedup, sort, eval, where, head, rare, top, parse, patterns, rename, fields, trendline, join, lookup, subquery, correlation, fillnull, flatten, expand, describe, AD, ML)
- Parser changes: grammar, AST construction, visitor patterns
- Analyzer: type resolution, field binding, scope handling
- Planner and Calcite rules: plan shape invariants, rule ordering, pushdown correctness
- Null handling, multi-valued fields, nested field semantics
- Read `references/checklist-opensearch-ppl.md` section "PPL Logic and Semantics"

**test-integration teammate:**
- Behavior changes have corresponding test updates
- integ-test or yamlRestTest coverage for behavior-changing PRs
- Snapshot/expected output changes are intentional
- Linked issue examples each have test coverage or rationale
- Negative-path tests for fragile logic
- Docs and doctest updates for user-visible changes
- Read `references/checklist-opensearch-ppl.md` section "Tests and Snapshots"
  and "Docs and Doctest"

**security-perf teammate:**
- Permission checks not bypassed or weakened
- Resource lifecycle: pagination/PIT create and cleanup paired correctly
- Cursor lifecycle consistent across success and failure paths
- Exception flow preserves root cause
- Request initialization (builders, explain state, context fields)
- API compatibility with expected OpenSearch versions
- Hot-path allocations, loops, sorting bounded
- Read `references/checklist-opensearch-ppl.md` section "Security and Permissions",
  "Execution and Lifecycle", and "Performance and Stability"

### Step 3: Collect and Deduplicate (Lead)

- Wait for all teammates to complete their tasks
- Collect findings from each teammate
- Deduplicate: if two teammates flag the same issue, keep the higher-severity
  version and credit both reviewers
- Resolve conflicting assessments: if teammates disagree on severity, use the
  evidence bar (section 8) to adjudicate

### Step 4: Evidence Bar (Lead)

For each finding in the merged set:

- Confirm exact location as `path:line`
- Verify concrete impact (what can break and for whom)
- Verify actionable next step (code fix, test gap, or follow-up validation)
- Mark assumptions when evidence is incomplete
- If tied to linked issue acceptance criteria, include `Spec ref: <issue/example>`

### Step 5: Approval Gate (Lead)

- Behavior change has test updates OR clear explanation
- Missing both integ-test and yamlRestTest for behavior-changing PRs is an
  approval gap (at least major; blocker for high-risk paths)
- Snapshot updates are intentional and semantically correct
- User-facing changes include docs/doctest updates OR explicit rationale
- Unresolved high-risk assumptions called out
- Merge conflicts reported separately as merge readiness info, not code-quality
  findings

### Step 6: Team Cleanup (Lead)

After producing the final review output:

- Shut down all teammates gracefully
- Clean up the team

## 7 Severity Rubric

| Severity   | Definition                                                              |
| :--------- | :---------------------------------------------------------------------- |
| `blocker`  | Correctness, security, or data integrity risk that can ship broken behavior |
| `major`    | High-confidence regression risk, missing critical test coverage, fragile design in hot path |
| `minor`    | Maintainability issue or localized risk with bounded blast radius        |
| `nit`      | Readability/style feedback with low risk                                 |
| `question` | Non-blocking clarification needed                                        |

Prefer fewer high-signal findings over a long list of low-value notes.

## 8 Finding IDs (MANDATORY)

Assign stable sequence IDs per severity in the final merged output:
`blocker 1`, `blocker 2`, `major 1`, `minor 1`, `nit 1`, `question 1`.

IDs are local to each review output. Keep numbering deterministic in report
order.

## 9 Comment Style (MANDATORY)

- Keep review comments concise and engineer-to-engineer
- Direct wording; avoid formal/ceremonial phrasing
- Keep each finding focused on one risk and one next step

## 10 Publish Review Comments (on request)

When the user asks to publish specific findings: `publish blocker 1`

Required steps:

1. Resolve finding ID to `path`, `line`, and comment body from the current review output
2. Resolve PR metadata: `gh pr view <pr-url-or-number> --json number,headRefOid`
3. Publish line comment:
   ```
   gh api repos/<owner>/<repo>/pulls/<pr-number>/comments \
     -f body='<comment body>' \
     -f commit_id='<headRefOid>' \
     -f path='<file path>' \
     -F line=<line> \
     -f side='RIGHT'
   ```

### Publishing Guidelines

- Keep comment text concise and engineer-to-engineer
- Publish only explicitly requested finding IDs
- If a finding references multiple lines, publish on primary line
- If line mapping is outdated, report failure and ask for confirmation

### GitHub Publish Body Format (MANDATORY)

- Natural engineer-to-engineer prose (1-3 short sentences)
- Do NOT include Finding ID, severity label, or section headers
- Include: (1) concrete observation tied to code/spec, (2) why it matters, (3) clear requested change

## 11 Output Format (STRICT)

```
## PR Change Summary

- <what changed>
- <main modules/files touched>
- <behavior and test/docs impact>

## Team Review Coverage

| Reviewer           | Areas Covered                                    | Findings |
| :----------------- | :----------------------------------------------- | :------- |
| ppl-logic          | PPL semantics, parsing, planning, Calcite rules  | N        |
| test-integration   | Test coverage, integ-test, snapshots, docs        | N        |
| security-perf      | Security, performance, resource lifecycle         | N        |

## Review Findings

### Blocker Issues

[blocker 1] path:line - Impact. Actionable fix or next step. (Reviewer: <name>)

### Major Issues

[major 1] path:line - Impact. Actionable fix or next step. (Reviewer: <name>)

### Minor Issues

[minor 1] path:line - Impact. Actionable fix or next step. (Reviewer: <name>)

### Nit Issues

[nit 1] path:line - Impact. Actionable fix or next step. (Reviewer: <name>)

### Questions

[question 1] path:line - Clarifying question. (Reviewer: <name>)

## Follow-up Questions

- Question 1
- Question 2

## Testing Recommendations

- Recommendation 1
- Recommendation 2

## Approval

- Ready for approval | Not ready for approval (list missing checklist items)

## Merge Readiness (informational)

- Clean | Conflicting
```

For PRs with no issues:

- Include `## PR Change Summary` with change bullets
- Include `## Team Review Coverage` table
- Include `## Review Findings` with `No blocker/major/minor findings.`

### Output Hygiene Rules

- Do NOT include execution task logs, TODO blocks, tool checklists, or command audit traces
- Do NOT include teammate coordination messages or internal team chatter
- Keep output focused on summary, coverage, findings, questions, testing recommendations, approval, merge readiness

## 12 References

- Read `references/checklist-opensearch-ppl.md` for PPL subsystem checks and approval gates
- Read `references/review-patterns.md` for high-signal finding patterns and comment phrasing
- Use `assets/templates/review-comment.md` for preformatted comment block
- Use `assets/templates/pr-line-comment.md` for publishing comments to GitHub PR lines
- Use `assets/templates/team-summary.md` for team review coverage table
