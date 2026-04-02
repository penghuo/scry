# OpenTelemetry Resources — Reference Summary

> Source: https://opentelemetry.io/docs/concepts/resources/
> Spec: https://opentelemetry.io/docs/specs/otel/resource/sdk/

## What Are OTel Resources?

A **Resource** is an immutable set of key-value attributes that identifies the **entity producing telemetry**. It answers "who emitted this signal?" — the process, container, pod, host, cloud instance, or service that generated a trace, metric, or log record.

Resources are attached at provider initialization time (TracerProvider, MeterProvider, LoggerProvider) and cannot be changed afterward. Every span, metric, and log record produced by that provider inherits the same resource attributes.

## How Resources Identify Service / Instance / Environment

Three resource attributes form the core identity tuple:

| Attribute | Purpose | Example |
|---|---|---|
| `service.name` | Logical name of the service | `checkout-service` |
| `service.instance.id` | Unique identity of a specific running instance | `i-0abc123def` |
| `deployment.environment.name` | Deployment environment (prod, staging, etc.) | `production` |

The SDK auto-assigns `service.name = "unknown_service"` if not explicitly set. Best practice is to always set it via code or `OTEL_SERVICE_NAME` env var.

The SDK also auto-populates: `telemetry.sdk.name`, `telemetry.sdk.language`, `telemetry.sdk.version`.

## Resource Attributes

Resource attributes are standard OTel `Attributes` (key-value pairs). Semantic conventions define well-known attribute namespaces:

- **Service**: `service.name`, `service.version`, `service.instance.id`
- **Host**: `host.name`, `host.id`, `host.arch`
- **Process**: `process.pid`, `process.runtime.name`
- **Container**: `container.id`, `container.image.name`
- **Kubernetes**: `k8s.pod.name`, `k8s.namespace.name`, `k8s.deployment.name`
- **Cloud**: `cloud.provider`, `cloud.region`, `cloud.account.id`
- **OS**: `os.type`, `os.version`
- **Deployment**: `deployment.environment.name`

Custom attributes can be added via code or the `OTEL_RESOURCE_ATTRIBUTES` env var:
```
OTEL_RESOURCE_ATTRIBUTES=deployment.environment.name=production,service.version=1.2.3
```

## Resource Detectors

Resource detectors are SDK plugins that **automatically discover** resource attributes from the runtime environment. They run at initialization and return a Resource that gets merged with user-provided attributes.

Built-in detector names (reserved by SDK):
- `container` → populates `container.*`
- `host` → populates `host.*`, `os.*`
- `process` → populates `process.*`
- `service` → populates `service.name` (from `OTEL_SERVICE_NAME`), `service.instance.id`

Platform/vendor detectors (separate packages): Docker, Kubernetes, EKS, AKS, GKE, AWS EC2, GCP GCE, etc.

**Merge semantics**: When multiple detectors or user-provided resources overlap, the updating resource's values win. Schema URL conflicts between merged resources are treated as errors.

## How Resources Enable Signal Correlation

Resources are the **primary mechanism for correlating signals across telemetry types**:

1. **Cross-signal join key**: Since TracerProvider, MeterProvider, and LoggerProvider share the same Resource, all traces, metrics, and logs from a service instance carry identical resource attributes. Backends can join signals on `service.name` + `service.instance.id`.

2. **Investigation scoping**: When a trace reveals latency, resource attributes let you narrow to the exact container, pod, K8s deployment, or cloud instance. Jaeger groups these under the "Process" tab.

3. **Entity identification**: The `(service.name, service.instance.id, deployment.environment.name)` tuple uniquely identifies an investigation object — the specific service instance in a specific environment that produced the telemetry.

4. **Topology mapping**: Resource attributes like `k8s.deployment.name`, `cloud.region`, and `host.id` enable backends to reconstruct infrastructure topology and map dependencies.

5. **Immutability guarantee**: Because resources are set once at initialization and never change, all signals from a provider are guaranteed consistent — no risk of partial or inconsistent identity across signal types.

## Key Design Decisions

- Resources are **immutable** after creation — set once at provider init.
- Resource detection runs during **application startup** and must complete quickly.
- User-provided attributes take **priority** over environment-detected ones.
- Failure to detect resource info is NOT an error; errors during detection ARE.
- The `OTEL_RESOURCE_ATTRIBUTES` env var provides a deployment-time override mechanism.
