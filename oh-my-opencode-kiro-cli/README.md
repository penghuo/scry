# Oh-My-OpenCode → Kiro CLI Migration

This workspace mirrors **all features in `dev/docs/features.md`** of oh-my-opencode v3.2.1 using Kiro CLI artifacts.

## Layout
- `.kiro/config.json` — global toggles (tmux, Claude Code compat, experimental flags).
- `.kiro/agents/` — all core + planning agents (Sisyphus, Hephaestus, Oracle, Librarian, Explore, Multimodal-Looker, Prometheus, Metis, Momus, Atlas, Sisyphus-Junior).
- `.kiro/hooks/` — every built-in OMOC hook plus command hooks; triggers are manual commands for portability and include original OMOC event in `metadata.omoc_event`.
- `.kiro/settings/mcp.json` — built-in MCP servers (websearch/Exa, context7, grep_app, playwright) with OAuth store.
- `scripts/` — control-flow shims for slash workflows (ralph/ulw loops, refactor, start-work, init-deep, cancel-ralph).
- `.kiro/prompts/` and `.kiro/skills/` — prompts and skills mirrored from OMOC set.

## Command Equivalents
- `/ulw-loop "goal" --completion-promise=... --max-iterations=100` → `scripts/ulw-loop.sh "goal" [--completion-promise=...] [--max-iterations=N]`
- `/ralph-loop "goal"` → `scripts/ralph-loop.sh "goal"`
- `/cancel-ralph` → `scripts/cancel-ralph.sh`
- `/refactor <target>` → `scripts/refactor.sh <target> [--scope=...] [--strategy=...]`
- `/init-deep` → `scripts/init-deep.sh [goal]`
- `/start-work [plan]` → `scripts/start-work.sh [plan]`

All commands also exist as manual hooks (`command-*.json`) callable via `kiro-cli hook run --command <name> --message "..."`.

## Hooks (1:1 with OMOC)
Context/Injection: directory-agents-injector, directory-readme-injector, rules-injector, compaction-context-injector

Productivity/Control: keyword-detector, think-mode, ralph-loop, start-work, auto-slash-command

Quality/Safety: comment-checker, thinking-block-validator, empty-message-sanitizer, edit-error-recovery

Recovery/Stability: session-recovery, anthropic-context-window-limit-recovery, background-compaction

Truncation: grep-output-truncator, tool-output-truncator

Notifications/UX: auto-update-checker, background-notification, session-notification, agent-usage-reminder

Task Mgmt: task-resume-info, delegate-task-retry

Integration: claude-code-hooks, atlas, interactive-bash-session, non-interactive-env

Specialized: prometheus-md-only

## MCP / Skills
- Built-in MCPs: websearch (Exa AI), context7, grep_app, playwright (skill-embedded). OAuth tokens stored at `~/.config/opencode/mcp-oauth.json`.
- Skills: playwright, frontend-ui-ux, git-master, agent-browser, dev-browser. Disable via `disabled_skills` in config.

## Experimental Flags
`config.json` carries OMOC flags: preemptive_compaction, aggressive_truncation, auto_resume, dcp. Adjust as needed.

## Next Validation Steps
1) `kiro-cli agent validate --path .kiro/agents/*.json`
2) `kiro-cli hook run --command ulw-loop --message "Test"` (or run scripts)
3) Test MCP connectivity: `kiro-cli mcp status`

This setup keeps OMOC feature coverage while using Kiro CLI runtime. Update prompts/agents as models evolve.
