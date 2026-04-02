# OpenTelemetry Semantic Conventions — Reference Summary

**Source:** https://opentelemetry.io/docs/concepts/semantic-conventions/ and https://opentelemetry.io/docs/specs/semconv/
**Version:** 1.40.0 (current as of fetch date)

## What Semantic Conventions Define

OTel Semantic Conventions are a standardized set of attribute names, types, meanings, and valid
values that provide consistent meaning to telemetry data across codebases, libraries, and platforms.
They specify span names and kinds, metric instruments and units, and log/event attribute schemas.

The core benefit: a common naming scheme enabling **cross-service correlation and consumption** of
telemetry data without per-team or per-vendor translation layers.

## How They Standardize Telemetry Signals

Conventions are defined per signal type:

- **Traces:** Span names, span kinds, status codes, standard attributes (e.g., `http.request.method`,
  `db.system`, `rpc.method`). Enables distributed trace correlation across service boundaries.
- **Metrics:** Instrument names, units, attribute dimensions. Standardizes metric semantics so
  dashboards and alerts are portable (e.g., `http.server.request.duration`).
- **Logs:** Structured log body and attribute schemas, exception recording conventions. Enables
  log-to-trace correlation via shared context attributes.
- **Profiles:** Continuous profiling semantic attributes (newer signal, added 2025).
- **Resources:** Identity attributes for the entity producing telemetry — `service.name`,
  `service.version`, `deployment.environment`, `host.id`, `k8s.pod.name`, etc.

## Key Convention Categories

| Category | Scope | Investigation Relevance |
|----------|-------|------------------------|
| **HTTP** | Client/server spans & metrics | Request tracing, latency analysis, error rates |
| **Database** | DB call spans & metrics (SQL, NoSQL, etc.) | Query performance, connection issues |
| **RPC/gRPC** | Remote procedure call spans & metrics | Service-to-service call failures |
| **Messaging** | Kafka, SQS, SNS, RabbitMQ spans | Async workflow debugging |
| **Exceptions** | Exception events on spans and logs | Root cause identification |
| **FaaS** | Lambda/serverless function spans | Cold start, timeout investigation |
| **System** | CPU, memory, disk, network metrics | Infrastructure-level diagnosis |
| **Resource** | Service identity, cloud, K8s, host, container | Scoping investigations to specific deployments |
| **Cloud Providers** | AWS SDK, GCP, Azure-specific attributes | Cloud API call tracing |
| **Generative AI** | LLM/agent spans, token metrics, MCP | AI system observability (emerging) |
| **CICD** | Pipeline spans, logs, metrics | Deployment-correlated incidents |

## Attribute Registry

All attributes live in a central **Registry** — a flat namespace of reusable attribute definitions
(90+ attribute groups: HTTP, DB, K8s, Cloud, Error, Network, etc.). Convention specs reference
registry attributes rather than redefining them, ensuring consistency across signals.

## Requirement Levels

Attributes use RFC 2119-style requirement levels:
- **Required** — MUST be provided
- **Conditionally Required** — MUST when condition is met
- **Recommended** — SHOULD be provided
- **Opt-In** — MAY be provided, often high-cardinality

## Relevance to Investigation-First Observability

1. **Correlation across signals:** Shared attribute names (`service.name`, `trace_id`, `span_id`)
   enable jumping from a metric anomaly → trace → log → resource without manual mapping.
2. **Queryable by convention:** Investigation tools can build queries using well-known attribute
   names (e.g., filter by `error.type`, `http.response.status_code`, `db.system`).
3. **Resource scoping:** Resource conventions let investigators scope to specific service versions,
   deployment environments, K8s namespaces, or cloud regions.
4. **Exception semantics:** Standardized exception recording (`exception.type`, `exception.message`,
   `exception.stacktrace`) enables automated root-cause extraction.
5. **T-shaped signals:** OTel's "T-shaped" convention pattern links a broad metric (the horizontal)
   to deep traces/logs (the vertical) for the same operation — directly supporting the
   "detect → investigate → resolve" workflow.
6. **Naming stability:** Versioned conventions with stability guarantees mean investigation tooling
   can rely on attribute names across OTel SDK upgrades.
