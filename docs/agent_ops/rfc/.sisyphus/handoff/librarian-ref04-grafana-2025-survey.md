# Grafana Labs 3rd Annual Observability Survey (2025)

**Source:** https://grafana.com/observability-survey/2025/
**Methodology:** 1,255 responses collected Sept 18, 2024 – Jan 2, 2025 via website, newsletters, social media, and in-person events.

---

## RFC-Relevant Statistics (Verified)

### Observability Spend
- **Mean: 17% of total compute infrastructure spend** ✅ (confirmed)
- Median: 10%, Mode: 10%
- Wide variance: some spend near 0%, others exceed 100% of compute spend
- Based on 294 valid responses (optional open-ended question, inconsistent responses removed)

### Tool Sprawl
- **Average of 8 observability technologies per company** ✅ (confirmed; down from 9 in 2024)
- **101 different observability technologies** cited across all respondents
- **Grafana users configure an average of 16 data sources** ✅ (confirmed)
  - Companies >5,000 employees: avg 24 data sources
  - Companies ≤10 employees: avg 6 data sources
  - SREs avg 18 data sources; developers avg 10

### Cost as Selection Factor
- **74% say cost is a top priority for selecting tools** ✅ (confirmed)
- Cost ranks ahead of ease of use and interoperability
- 88% of those who say observability "costs too much" also cite cost as important selection criteria

### Top Challenges
- 39% — Complexity/overhead (most cited impediment) ✅
- 38% — Signal-to-noise / too much noise
- 37% — Costs too much
- 29% — Costs too difficult to predict/budget
- 28% — Vendor lock-in
- 24% — Getting adoption within company

---

## Investigation Workflows & Incident Response

- **Alert fatigue is the #1 obstacle to faster incident response** across nearly all roles
  - Exception: engineering managers slightly more likely to cite "painful incident coordination across teams"
- Engineering managers most likely to cite "limited data across incidents" (18%)
- Centralized observability is dominant: 61% use centralized teams (support or operations model)
- Anecdotal: centralized observability reduced MTTR by 40% (one respondent), saved ~$25K/quarter

---

## AI/ML Adoption

- **Most wanted AI/ML features:**
  1. Training-based alerts (fire when metric deviates from pattern) — 31%
  2. Faster root cause analysis (automated checks, signal interpretation, suggestions) — 28%
  3. Reduction in unused/underutilized resources and telemetry — 16%
  4. Guidance for setup (monitoring, SLOs, alerting) — 11%
  5. Ongoing anomaly detection across services — 11%
- Smaller orgs favor training-based alerts; larger/more complex orgs favor root-cause analysis
- 27% of engineering directors/managers prioritize AI/ML features in tool selection (vs. 19% overall)
- LLM observability is emerging: 47% investigating/building POC, but only 7% in production

---

## Additional Context for RFC

### Telemetry Adoption
- Metrics: 95%, Logs: 87%, Traces: 57%, Profiles: 16%
- Traces growing; financial services leads (65%), telecom lags (37%)

### Open Source
- 71% use Prometheus and OpenTelemetry in some capacity
- 34% use both in production
- 76% use open source licensing for observability in some capacity
- Commercial-only/mostly usage doubled YoY (10% → 24%)

### SaaS Trend
- 37% mostly/only SaaS (up 42% YoY)
- 57% still mostly/only self-managed
- Equal split (SaaS/self-managed) dropped from 22% to 6%

### Full-Stack Observability
- 85% using unified infrastructure + application observability in some capacity
- 51% investigating/building POC for unified observability
- 50% investigating/building POC for SLOs

### Executive Engagement
- 49% say CTO/C-level or VP-level considers observability business-critical
- C-suite engagement correlates with more mature observability practices
