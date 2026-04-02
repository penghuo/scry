# Datadog Bits AI SRE — Investigation Process Reference

> Source: https://docs.datadoghq.com/bits_ai/bits_ai_sre/investigate_issues/
> Retrieved: 2025-07-14

## Overview

Bits AI SRE is Datadog's AI-powered incident investigation agent. It autonomously
investigates production issues by querying telemetry, forming hypotheses, and
converging on root causes — operating as an agentic loop rather than a static dashboard.

## Investigation Process (Hypothesis-Evidence-Conclusion Loop)

Bits AI SRE operates in a **continuous loop of observation, reasoning, and action**:

1. **Hypothesis formation**: Forms hypotheses about potential root causes based on
   the alert context (monitor query, service tags, time window).
2. **Tool-based evidence gathering**: Uses its tools to query telemetry data —
   metrics, traces, logs, events, change tracking, etc.
3. **Validation/invalidation**: Each step builds on prior findings. As new evidence
   emerges, it updates its understanding and refines reasoning.
4. **Chaining**: Chains together additional investigative steps, adapting and
   course-correcting based on what it discovers.
5. **Convergence**: Continues until it converges on the most likely root cause.

This is explicitly described as an agent that "course-corrects" — not a linear
pipeline but an adaptive reasoning loop.

## Handling Inconclusive Results

At the end of an investigation, Bits AI SRE either:
- Presents a **clear, evidence-backed conclusion**, or
- **Marks the investigation as inconclusive** when available data is insufficient
  to support a defensible conclusion.

Key design choice: it does NOT fabricate conclusions. It explicitly acknowledges
when data is insufficient rather than guessing.

## Telemetry / Data Sources

### Datadog-native products:
- Metrics
- APM traces
- Logs
- Dashboards
- Events
- Change Tracking (deployments, config changes)
- Source code (GitHub only)
- Watchdog (anomaly detection)
- Real User Monitoring (RUM)
- Network Path
- Database Monitoring
- Continuous Profiler

### Third-party integrations (Preview):
- Grafana, Dynatrace, Sentry, Splunk, ServiceNow, Confluence

### Service scoping best practice:
For monitors associated with a service, adding a service tag or filtering/grouping
by service helps Bits AI SRE correlate data more accurately.

## Entry Points (How Investigations Start)

- **Manual**: From monitor alerts, APM latency graphs, APM Watchdog stories, or
  free-form chat prompts (e.g., "Investigate high CPU in ai-gateway in prod")
- **Automatic**: Monitors can be configured to auto-trigger investigations on
  alert state transitions (not warn, not no-data, not renotifications)
- **Slack**: Reply to monitor notification with `@Datadog Investigate this alert`
  or mention `@Datadog` with a description in any channel/thread

## Supported Monitor Types

Metric, Anomaly, Forecast, Integration, Outlier, Logs, APM (APM Metrics only),
Synthetics API and Browser tests (Preview).

## Investigation Display Modes

- **Agent Trace view**: Real-time, step-by-step record of the agent's reasoning
  process — shows how it evaluates evidence and makes decisions during investigation.
- **Investigation view**: Post-completion structured tree-based visualization of
  the investigative path for understanding findings at a glance.

## How It Differs from Traditional Dashboards

| Aspect | Traditional Dashboards | Bits AI SRE |
|--------|----------------------|-------------|
| Mode | Passive — human reads charts | Active — agent queries and reasons |
| Reasoning | Human must correlate signals | Agent forms/tests hypotheses autonomously |
| Adaptivity | Static layout | Dynamically chains investigative steps |
| Conclusion | Human interprets | Agent presents evidence-backed conclusion or marks inconclusive |
| Data scope | Pre-configured widgets | Queries across 12+ telemetry types on demand |
| Trigger | Human opens dashboard | Auto-triggered on alert or invoked via chat |

## RFC-Relevant Patterns

1. **Agentic loop architecture**: Observe → hypothesize → act → validate → repeat
2. **Explicit inconclusiveness**: Refuses to guess when evidence is insufficient
3. **Multi-signal correlation**: Crosses metrics/traces/logs/events/changes in a
   single investigation rather than siloed views
4. **Context-seeded investigations**: Quality of investigation depends on input
   specificity (service tags, time windows, symptom descriptions)
5. **Dual-view transparency**: Agent Trace for debugging the agent's reasoning;
   Investigation view for consuming results
6. **Reports/analytics**: Tracks investigation count by monitor/user/service/team
   and mean time to conclusion for measuring on-call efficiency impact
