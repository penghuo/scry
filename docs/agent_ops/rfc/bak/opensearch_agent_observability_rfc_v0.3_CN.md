# RFC: OpenSearch 面向人类和 Agent 可观测性的调查框架

## 状态

草案

## 1. 摘要

OpenSearch 已经提供了可观测性平台的核心构建模块：基于 OTel 的数据摄取、Data Prepper 管道、Trace Analytics、Event Analytics、PPL，以及包括 MCP 支持在内的 agent / tool 集成。Trace Analytics 依赖于 Data Prepper 的 trace 管道和 service-map 生成。Data Prepper 已经支持聚合处理，包括计数和显式边界直方图。OpenSearch 还通过 ML Commons 暴露了 agent 和 MCP 集成接口。

OpenSearch 目前**尚未**提供的是一流的调查模型。日志、指标、链路追踪和 agent 事件可以被存储和查询，但系统并未提供用于信号发现、早期范围缩小、调查状态、证据集或结论状态的稳定对象。

本 RFC 在现有 OpenSearch 可观测性技术栈之上引入了一个最小化的调查框架。第一阶段添加四个持久化对象和两个 API。

**对象**
1. Signal Catalog Record
2. Investigation Summary
3. Investigation Context
4. Evidence Set

**API**
1. `discover`
2. `narrow`

目标不是重新定义遥测语义。OpenTelemetry 仍然是基础 service、resource、environment、trace 和 span 语义的权威来源。本 RFC 在这些基础之上添加了一个 OpenSearch 特有的调查组织层。OpenTelemetry 还为 GenAI / agent span 提供了处于**开发状态**的语义约定，本 RFC 在适用的情况下复用这些约定，而非重新定义。

## 2. 问题陈述

现有的可观测性系统围绕功能入口进行组织：仪表盘、搜索/查询、链路追踪探索、日志探索和告警调查。这种模型适用于交互式使用，但它并未将调查过程本身视为一流的系统能力。OpenSearch 目前遵循相同的通用模式：可观测性能力已经存在，但它们围绕产品界面而非可复用的调查工作流进行组织。

人类和 agent 通常以类似的方式调查事件：观察异常、缩小范围、比较候选项、收集证据，然后决定是否采取行动。问题不在于 agent 使用了不同的方法。问题在于调查过程的大部分仍然需要跨工具、数据源和信号手动拼接。

这造成了四个直接的差距。

### 2.1 调查入口、对象识别和上下文收敛能力薄弱

调查很少从零开始。它通常从告警、部署、用户报告、异常链路追踪或类似触发器开始。目前系统并未显式提供回答以下问题所需的结构：

- 正在调查的对象是什么
- 该对象存在哪些信号
- 这些信号存储在哪里
- 哪些数据是相关联的

人类和 agent 并不天然知道指标、日志和链路追踪在哪里，也不知道它们之间的关系。他们依赖系统来显式地呈现调查对象、数据位置、关系和入口上下文。

### 2.2 跨信号缩小范围和候选项优先级排序能力薄弱

调查不是关于查看更多数据，而是关于更快地缩小范围。真实的调查跨越指标、链路追踪、日志、部署和依赖关系，以识别最可能涉及的系统、维度或时间窗口。

另一个关键步骤是候选项优先级排序。工程师必须决定是先检查部署、下游服务、租户还是路径。目前这在很大程度上仍然是一个手动比较过程。

### 2.3 调查状态、证据和结论边界能力薄弱

大多数可观测性系统擅长存储原始遥测数据和最终查询结果。它们在表达以下方面能力薄弱：

- 已经检查了什么
- 形成了哪些假设
- 排除了什么
- 证据链处于什么状态
- 当前可以得出什么级别的结论

调查并不总是产生确定的根因。`inconclusive`（无定论）通常是一个有效的结果，需要被显式表示。

### 2.4 跨系统流程语义不一致

当调查跨越多个系统和工具时，流程对象（如任务、步骤、证据和操作）变得不一致。这使得复用、审计和自动化更加困难。

## 3. 目标

第一阶段的目标是：

1. 使给定调查范围内的可用信号可被发现
2. 提供早期缩小范围的输入，无需重新扫描所有原始遥测数据
3. 将调查状态和证据持久化为机器可读的对象
4. 通过稳定的 API 暴露这些对象
5. 使 `inconclusive` 成为一流的结果

## 4. 非目标

本 RFC **不**尝试：

- 重新定义 OTel 基础语义
- 重新设计 OpenSearch 存储引擎
- 将基于 sketch 的摘要作为第一阶段的依赖
- 标准化所有跨厂商的调查语义
- 构建一个独立的仅面向 agent 的可观测性系统
- 在第一阶段解决所有 UI 流程

## 5. 现状

OpenSearch 已经具备第一阶段调查框架所需的最低技术基础：

- 通过 Data Prepper 和 trace 管道实现的 **OTel 数据摄取和 Trace Analytics**
- 通过 Data Prepper service-map 处理器实现的 **service map 生成**
- 用于交互式分析的**基于 PPL 的 Event Analytics**
- Data Prepper 目前已支持的**聚合处理器对计数和显式边界直方图的支持**。这很重要，因为第一阶段可以使用派生指标和直方图，而无需依赖 sketch 基础设施。
- 通过 ML Commons 和 MCP 支持实现的 **Agent / tool / MCP 集成接口**

缺失的部分不是孤立的数据摄取或查询能力。缺失的部分是一组可复用的调查对象和调查 API。

## 6. 设计原则

### 6.1 以调查路径为中心进行设计

优先考虑改善调查路径的能力，而非孤立的功能增强。

### 6.2 优先考虑人类和 agent 共享的能力

首先弥合人类和 agent 都需要的对象识别、信号发现、范围缩小、状态表达和边界表达方面的差距。然后添加面向 agent 的消费模式。

### 6.3 使过程显式化，而不仅仅是结果

系统必须表示已检查的范围、嫌疑集、证据集、结论状态和下一步操作，而不仅仅是原始命中结果或最终图表。

### 6.4 优先考虑程序化消费

UI 仍然重要，但核心调查对象和状态不能仅存在于页面交互中。

### 6.5 使证据、结论和操作边界显式化

系统必须区分线索、证据、有支撑的结论，以及哪些结论有资格进行后续操作。

### 6.6 在现有 OpenSearch 和 OTel 能力基础上渐进式演进

不重新定义 OTel 基础。复用 Data Prepper、Trace Analytics、PPL、MCP 及相关能力。在它们之上添加调查组织层。

## 7. 提议范围

第一阶段引入四个具体的系统对象和两个具体的 API。

### 7.1 第一阶段对象

1. Signal Catalog Record
2. Investigation Summary
3. Investigation Context
4. Evidence Set

### 7.2 第一阶段 API

1. `discover`
2. `narrow`

这些足以实现第一个端到端的调查循环。
## 8. 数据模型

### 8.1 Signal Catalog Record

用途：回答第一个调查问题：对于当前对象，存在哪些信号，它们存储在哪里，覆盖了什么时间范围，以及如何进行关联。

Schema：

```json
{
  "object_key": {
    "service_name": "checkout",
    "environment": "prod",
    "instance_id": "i-123",
    "deployment_id": "deploy-2026-03-31"
  },
  "signal_type": "trace",
  "source_locator": {
    "kind": "index_pattern",
    "value": "otel-v1-apm-span-*"
  },
  "time_coverage": {
    "start": "2026-03-31T00:00:00Z",
    "end": "2026-03-31T23:59:59Z"
  },
  "correlation_keys": [
    "service.name",
    "trace_id",
    "span_id"
  ],
  "resolution": "raw",
  "freshness_ts": "2026-03-31T23:59:59Z"
}
```

说明：

- `object_key` 在可用时复用现有的 OTel 身份标识。
- `source_locator` 指向索引模式、别名或其他读取目标。
- `resolution` 用于区分原始数据与派生指标、直方图以及未来基于 sketch 的摘要。

### 8.2 Investigation Summary

用途：提供早期缩小范围的证据，而无需每个调查步骤都重新扫描原始数据。

Phase 1 仅支持：

- `count`
- `histogram`
- `derived_metric`

这与 Data Prepper 目前已能生产的内容有意保持一致。Sketch 推迟到 P2。

Schema：

```json
{
  "summary_id": "sum-001",
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:05:00Z"
  },
  "source_signal": "trace",
  "summary_type": "histogram",
  "metric_name": "duration_ms",
  "payload": {
    "count": 12453,
    "sum": 9812334,
    "min": 12,
    "max": 9421,
    "buckets": [
      {"le": 100, "count": 7000},
      {"le": 500, "count": 11000},
      {"le": 1000, "count": 12100},
      {"le": 5000, "count": 12420}
    ]
  },
  "provenance": {
    "pipeline": "trace-aggregate",
    "materialized_from": "otel-v1-apm-span-*"
  },
  "freshness_ts": "2026-03-31T10:05:10Z"
}
```

### 8.3 Investigation Context

用途：持久化调查本身的状态。

Schema：

```json
{
  "investigation_id": "inv-123",
  "entry": {
    "type": "alert",
    "id": "alert-456"
  },
  "scope": {
    "object_key": {
      "service_name": "checkout",
      "environment": "prod"
    },
    "time_window": {
      "start": "2026-03-31T10:00:00Z",
      "end": "2026-03-31T10:30:00Z"
    }
  },
  "checked_signals": ["metric", "trace"],
  "suspect_set": [
    {"kind": "deployment", "id": "deploy-2026-03-31"},
    {"kind": "service", "id": "payment"}
  ],
  "state": "narrowed",
  "last_updated": "2026-03-31T10:07:00Z"
}
```

状态机：

- `open`
- `narrowed`
- `suspected`
- `inconclusive`
- `concluded`

有效转换：

| From | To | 触发条件 |
|---|---|---|
| `open` | `narrowed` | `narrow` 返回非空的 `suspect_set` |
| `open` | `inconclusive` | `discover` 或 `narrow` 未返回可用数据 |
| `narrowed` | `suspected` | 后续分析识别出一个具有支持证据的主要嫌疑对象 |
| `narrowed` | `inconclusive` | 所有候选对象已耗尽或证据仍然不足 |
| `suspected` | `concluded` | 结论以证据支持的状态被明确最终确定 |
| `suspected` | `inconclusive` | 存在矛盾证据或后续证据不足 |

Phase 1 中的无效转换：

- `open -> concluded`
- `open -> suspected`
- `inconclusive -> narrowed`
- `concluded -> any`

在 Phase 1 中，`inconclusive` 和 `concluded` 是终态。

### 8.4 Evidence Set

用途：将证据存储为机器可读的对象，而不仅仅是 UI 渲染。

Schema：

```json
{
  "evidence_id": "ev-001",
  "investigation_id": "inv-123",
  "evidence_type": "supporting_histogram",
  "related_object": {
    "kind": "deployment",
    "id": "deploy-2026-03-31"
  },
  "supporting_signals": ["trace", "metric"],
  "supporting_refs": [
    {"kind": "summary", "id": "sum-001"},
    {"kind": "query_result", "id": "qr-778"}
  ],
  "confidence": "medium",
  "completeness": "partial",
  "conclusion_impact": "supports_suspect"
}
```

允许的值：

- `confidence`：`low | medium | high`
- `completeness`：`partial | substantial | complete`
- `conclusion_impact`：`none | supports_suspect | rejects_suspect | supports_conclusion`

## 9. 存储规范

### 9.1 物理存储

Phase 1 将调查对象存储在 OpenSearch 管理的索引中。

| 对象 | 存储方式 | 命名 | 保留策略 | 说明 |
|---|---|---|---|---|
| Signal Catalog Record | system index | `.investigation-catalog-v1` | `freshness_ts` 后 30 天 | 按 `(object_key, signal_type, source_locator)` 进行 upsert |
| Investigation Summary | 按时间分区的 system index | `.investigation-summary-v1-YYYY.MM.DD` | 默认 14 天 | 写入后不可变 |
| Investigation Context | system index | `.investigation-context-v1` | 进入终态后 90 天 | 按 ID 更新 |
| Evidence Set | system index | `.investigation-evidence-v1` | 进入终态后 90 天 | 仅追加 |

### 9.2 访问控制

- 普通用户不需要直接访问索引。
- Phase 1 的访问通过调查 API 进行。
- 可以向特权角色授予管理和调试访问权限。

这些对象不会替代原始日志、链路追踪或指标。Signal catalog 和 summary 是读优化的辅助对象。Context 和 evidence 是状态对象。

## 10. API 规范

### 10.1 `discover`

用途：查找当前调查范围内所有可用的信号。

请求：

```json
POST /_plugins/_investigation/discover
{
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  }
}
```

成功且有匹配结果：

```json
{
  "catalog_records": [
    {
      "signal_type": "trace",
      "source_locator": {"kind": "index_pattern", "value": "otel-v1-apm-span-*"},
      "time_coverage": {
        "start": "2026-03-31T10:00:00Z",
        "end": "2026-03-31T10:30:00Z"
      },
      "correlation_keys": ["service.name", "trace_id", "span_id"],
      "resolution": "raw"
    },
    {
      "signal_type": "metric",
      "source_locator": {"kind": "index_pattern", "value": "otel-v1-derived-metrics-*"},
      "time_coverage": {
        "start": "2026-03-31T10:00:00Z",
        "end": "2026-03-31T10:30:00Z"
      },
      "correlation_keys": ["service.name"],
      "resolution": "derived_metric"
    }
  ]
}
```

成功但无匹配结果：

```json
{
  "catalog_records": [],
  "empty_reason": "no_signals_found"
}
```

无效请求：

```json
{
  "error_code": "invalid_request",
  "message": "object_key.service_name is required"
}
```

### 10.2 `narrow`

用途：利用现有摘要在扫描原始遥测数据之前缩小搜索空间。

Phase 1 恰好支持两种策略。

| strategy.kind | 所需输入 | 基线 | 输出意图 |
|---|---|---|---|
| `latency_regression` | 延迟类指标的 histogram 或 derived metric 摘要 | 紧接在前的等长时间窗口 | 识别与延迟偏移相关的嫌疑对象 |
| `error_spike` | 错误和请求总量的 count 或 derived metric 摘要 | 紧接在前的等长时间窗口 | 识别与错误率上升相关的嫌疑对象 |

在 Phase 1 中，任何其他值均为无效。

#### `latency_regression`

消费：

- `summary_type in {histogram, derived_metric}`
- `metric_name in {"duration_ms", "latency_ms", "request_latency_ms"}`

算法：

1. 为请求的对象范围选择当前窗口的摘要。
2. 选择紧接在前的等长基线窗口。
3. 按以下顺序（在可用时）生成候选维度：
   - `deployment_id`
   - 下游 `service_name`
   - `tenant`
4. 使用以下方式计算候选分数：
   - 如果存在 histogram，使用尾部偏移
   - 如果仅存在 derived metric，使用平均值或速率差值
5. 丢弃低于 `min_volume` 和 `min_delta_threshold` 的候选对象。
6. 将剩余候选对象作为排序后的 `suspect_set` 返回。

请求：

```json
POST /_plugins/_investigation/narrow
{
  "investigation_id": "inv-123",
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  },
  "strategy": {
    "kind": "latency_regression",
    "min_volume": 100,
    "min_delta_threshold": 0.20
  }
}
```

#### `error_spike`

消费：

- `summary_type in {count, derived_metric}`
- 同一范围内的错误计数和总请求计数

算法：

1. 选择当前窗口的摘要。
2. 选择紧接在前的等长基线。
3. 按候选维度计算错误率差值。
4. 按错误率增幅降序排列候选对象。
5. 丢弃低于 `min_volume` 和 `min_delta_threshold` 的候选对象。

请求：

```json
POST /_plugins/_investigation/narrow
{
  "investigation_id": "inv-789",
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  },
  "strategy": {
    "kind": "error_spike",
    "min_volume": 50,
    "min_delta_threshold": 0.10
  }
}
```

成功且有嫌疑对象：

```json
{
  "updated_state": "narrowed",
  "suspect_set": [
    {
      "kind": "deployment",
      "id": "deploy-2026-03-31",
      "reason": "error_rate_increase_after_deploy"
    },
    {
      "kind": "service",
      "id": "payment",
      "reason": "downstream_error_correlation"
    }
  ],
  "evidence_refs": [
    {"kind": "summary", "id": "sum-err-001"},
    {"kind": "summary", "id": "sum-err-002"}
  ],
  "next_actions": [
    {"kind": "pivot", "signal": "trace"},
    {"kind": "compare", "dimension": "deployment"}
  ]
}
```

成功但无可用摘要：

```json
{
  "updated_state": "inconclusive",
  "suspect_set": [],
  "evidence_refs": [],
  "next_actions": [],
  "empty_reason": "no_summaries_available"
}
```

调查未找到：

```json
{
  "error_code": "investigation_not_found",
  "message": "investigation_id inv-123 does not exist"
}
```

无效策略：

```json
{
  "error_code": "invalid_strategy",
  "message": "strategy.kind must be one of latency_regression,error_spike"
}
```
## 11. 端到端场景

### 11.1 场景 A：告警驱动的调查

#### A1. 告警触发

告警：`checkout latency p95 high`

系统创建：

```json
{
  "investigation_id": "inv-123",
  "entry": {"type": "alert", "id": "alert-456"},
  "scope": {
    "object_key": {"service_name": "checkout", "environment": "prod"},
    "time_window": {
      "start": "2026-03-31T10:00:00Z",
      "end": "2026-03-31T10:30:00Z"
    }
  },
  "state": "open"
}
```

#### A2. 发现

`discover(inv-123)` 返回：

- trace 数据源：`otel-v1-apm-span-*`
- metric 数据源：`otel-v1-derived-metrics-*`
- log 数据源：`app-logs-prod-*`

#### A3. 缩小范围

`narrow(inv-123, strategy=latency_regression)` 返回：

- 嫌疑对象：`deploy-2026-03-31`
- 嫌疑对象：下游服务 `payment`
- 证据引用：延迟直方图摘要
- 状态转换：`open -> narrowed`

#### A4. 后续跟进

后续查询可能会转向原始 trace 或 log，但调查已经从"我应该检查哪些数据？"推进到"我接下来应该检查哪个候选对象？"

### 11.2 场景 B：Agent 驱动的调查

#### B1. Agent 调用 `discover`

```json
POST /_plugins/_investigation/discover
{
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  }
}
```

#### B2. 系统返回可用信号

```json
{
  "catalog_records": [
    {
      "signal_type": "trace",
      "source_locator": {
        "kind": "index_pattern",
        "value": "otel-v1-apm-span-*"
      },
      "time_coverage": {
        "start": "2026-03-31T10:00:00Z",
        "end": "2026-03-31T10:30:00Z"
      },
      "correlation_keys": ["service.name", "trace_id", "span_id"],
      "resolution": "raw"
    },
    {
      "signal_type": "metric",
      "source_locator": {
        "kind": "index_pattern",
        "value": "otel-v1-derived-metrics-*"
      },
      "time_coverage": {
        "start": "2026-03-31T10:00:00Z",
        "end": "2026-03-31T10:30:00Z"
      },
      "correlation_keys": ["service.name"],
      "resolution": "derived_metric"
    }
  ]
}
```

#### B3. Agent 调用 `narrow`

```json
POST /_plugins/_investigation/narrow
{
  "investigation_id": "inv-789",
  "object_key": {
    "service_name": "checkout",
    "environment": "prod"
  },
  "time_window": {
    "start": "2026-03-31T10:00:00Z",
    "end": "2026-03-31T10:30:00Z"
  },
  "strategy": {
    "kind": "error_spike",
    "min_volume": 50,
    "min_delta_threshold": 0.10
  }
}
```

#### B4. 系统返回嫌疑对象和机器可读的证据

```json
{
  "updated_state": "narrowed",
  "suspect_set": [
    {
      "kind": "deployment",
      "id": "deploy-2026-03-31",
      "reason": "error_rate_increase_after_deploy"
    },
    {
      "kind": "service",
      "id": "payment",
      "reason": "downstream_error_correlation"
    }
  ],
  "evidence_refs": [
    {"kind": "summary", "id": "sum-err-001"},
    {"kind": "summary", "id": "sum-err-002"}
  ],
  "next_actions": [
    {"kind": "pivot", "signal": "trace"},
    {"kind": "compare", "dimension": "deployment"}
  ]
}
```

由于状态和证据都是机器可读的，Agent 无需从原始页面或临时笔记中重建调查历史。

## 12. 为什么这很重要

这不仅仅是一次内部整理，更是一个产品差异化优势。

正如评审中所指出的，Datadog Bits AI SRE 主要通过 UI 流程暴露调查功能。当前的差距在于缺乏正式的、机器可读的证据契约和程序化的调查状态 API。OpenSearch 可以通过从 Phase 1 开始就将调查状态、证据和缩小范围的输出作为一等 API 对象来实现差异化，而非仅作为 UI 层面的产物。

## 13. 解决方案如何解决前述问题

| 问题 | 解决方案 | 解决效果 |
|---|---|---|
| 调查入口、对象识别、上下文收敛 | Signal catalog + investigation context | 使信号可发现，使范围明确 |
| 跨信号缩小范围与优先级排序 | Investigation summaries + `narrow` API | 在原始扫描之前实现早期缩小范围 |
| 调查状态、证据、结论边界 | Investigation context + evidence set + conclusion states | 使状态和证据明确且可复用 |
| 跨系统流程语义 | 共享 investigation 对象 + API | 提供具体的 OpenSearch 侧流程模型，即使更广泛的跨厂商标准化仍是未来工作 |

## 14. 发布计划

### P0

- Signal catalog
- 基于现有直方图/派生指标的 Investigation summaries
- Investigation context
- Evidence set
- Conclusion state
- `discover` API
- `narrow` API

### P1

- `pivot`、`compare`、`continue` API
- entry context 增强
- 面向 MCP 的调查 API 暴露

### P2

- 可合并的 sketch
- 更广泛的 agent 遥测对齐
- 更丰富的治理规则和更广泛的跨系统语义

这个顺序是经过深思熟虑的。P0 建立了调查的最小闭环：发现、预缩小范围、存储状态和存储证据。P1 使该闭环更丰富、对 agent 更友好。P2 添加需要更多基础设施或更广泛语义对齐的能力。

## 15. 风险与缓解措施

### 15.1 增加的复杂性

这个风险是真实存在的。行业数据指向整合趋势，而复杂性本身就是可观测性领域的主要障碍。危险在于这个 RFC 可能看起来像又一个抽象层。

缓解措施：

- Phase 1 有意保持狭窄范围：四个持久化对象和两个 API。
- 它不引入新的面向终端用户的产品界面。
- 它将已经隐式存在于 OpenSearch 可观测性、notebooks、assistant 流程以及 agent/tool 集成中的调查结构外部化。
- 设计目标是减少隐藏的调查复杂性，而非增加第二个控制平面。

### 15.2 OpenSearch 可观测性的基础差距

当前的 trace 分析和可观测性功能不如更成熟的集成平台那样广泛。该框架不能假设缺失的基础已经被解决。

缓解措施：

- Phase 1 仅依赖现有的 OTel 摄入、Data Prepper 管道、计数/直方图以及当前的分析读取路径。
- Sketch 被明确推迟到 P2。

### 15.3 Baggage 安全性

OTel baggage 是明文的，且会广泛传播。以这种方式携带的调查上下文如果使用不当可能会泄露。

缓解措施：

- Entry context 增强是可选的，Phase 1 不要求。
- 必须限制为非敏感标识符。

### 15.4 并发访问

多个人类或 agent 可能同时操作同一个调查。

缓解措施：

- `Investigation Context` 通过 ID 更新。
- Phase 1 应在状态更新时使用乐观并发控制。
- 终态是不可变的。

## 16. 标准边界

### 复用自 OpenTelemetry 的部分

- 服务标识
- 实例标识
- 部署环境
- trace / span 关联
- 开发状态中的 GenAI / agent 语义约定

### OpenSearch 特有的扩展

- signal catalog
- investigation summaries
- investigation context
- evidence set
- conclusion state
- investigation API

边界很简单：OpenTelemetry 仍然是遥测语义的权威来源；OpenSearch 添加调查组织层。
