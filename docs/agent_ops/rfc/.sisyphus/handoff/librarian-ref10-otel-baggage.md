# OpenTelemetry Baggage — Reference Summary

**Source:** https://opentelemetry.io/docs/concepts/signals/baggage/
**Spec:** https://opentelemetry.io/docs/specs/otel/overview/#baggage-signal
**Retrieved:** 2025-07-14

## What Is OTel Baggage?

Baggage is a **key-value store** that rides alongside OTel Context. It allows arbitrary
data to be propagated across service boundaries within a distributed system. Baggage is
one of the four OTel signal types (alongside Traces, Metrics, Logs).

Key properties:
- Key-value pairs attached to the current context
- Propagated automatically via context propagation (typically W3C Baggage HTTP header)
- Available to any service in the request path that participates in OTel propagation
- **Not** automatically added to spans/metrics/logs — must be explicitly read and attached

## How Propagation Works

1. A service sets baggage entries (e.g., `clientId=abc123`) on the current context
2. OTel instrumentation serializes baggage into HTTP headers (W3C `baggage` header)
3. Downstream services receive and deserialize the baggage automatically
4. Downstream code can read baggage values and attach them to local telemetry signals

Baggage propagation is handled by **Context Propagators** — pluggable components that
inject/extract context across process boundaries (HTTP headers, message queue metadata, etc.).

## Use Cases

- **Request-scoped metadata**: User IDs, account IDs, product IDs, origin IPs
- **Cross-service correlation**: Making entry-point data available deep in the call graph
- **Deeper telemetry analysis**: e.g., "which users experience the slowest DB calls?"
- **Feature flag context**: Propagating experiment/variant identifiers
- **Tenant identification**: Multi-tenant systems passing tenant context downstream

## Relevance to Investigation Context Propagation

Baggage is a strong candidate for carrying **investigation entry context** across services:

- An investigation's `entry_id`, `investigation_id`, or `session_id` can be set as baggage
  at the entry point (e.g., API gateway or agent orchestrator)
- All downstream services automatically receive this context without code changes
  (assuming OTel instrumentation is in place)
- Downstream services can use a **BaggageSpanProcessor** to auto-attach baggage values
  as span attributes, enabling investigation-scoped trace queries
- Works across heterogeneous service boundaries (HTTP, gRPC, messaging) via standard
  W3C Baggage header

**Key design consideration:** Baggage values must be explicitly promoted to span/metric/log
attributes — they are NOT automatically correlated. A BaggageSpanProcessor or manual
extraction is required.

## Limitations

- **No size guarantees**: The W3C Baggage spec recommends support for at least 8192 bytes,
  but intermediaries (proxies, load balancers) may truncate headers
- **No built-in integrity checks**: Any participant can modify or forge baggage entries
- **Not attributes**: Baggage is a separate store; forgetting to extract means data is lost
- **Performance**: Large baggage payloads add overhead to every network request
- **No encryption**: Values are plaintext in HTTP headers

## Security Considerations

- Baggage is transmitted in **plaintext HTTP headers** — visible to network inspection
- Automatic instrumentation propagates baggage to **all** outbound requests, including
  third-party APIs — sensitive data (PII, tokens) can leak unintentionally
- No authentication or integrity mechanism — downstream services cannot verify origin
- **Recommendation**: Only put non-sensitive, low-cardinality identifiers in baggage
- For investigation context: use opaque IDs (not raw user data) as baggage values

## API Summary

| Operation | Description |
|-----------|-------------|
| `set(key, value)` | Add/update a baggage entry |
| `get(key)` | Retrieve a baggage value |
| `remove(key)` | Remove a baggage entry |
| `getAll()` | List all baggage entries |

Baggage entries can optionally include **metadata** (opaque string for propagation hints).
