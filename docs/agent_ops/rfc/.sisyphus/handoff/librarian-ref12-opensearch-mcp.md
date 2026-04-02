# OpenSearch MCP Integration — Reference Summary

> Source: [OpenSearch MCP Docs](https://docs.opensearch.org/latest/ml-commons-plugin/agents-tools/mcp/index/) (v3.0+)
> Fetched: 2025-07-17

## Overview

OpenSearch 3.0 introduced native MCP (Model Context Protocol) support in its ML Commons plugin,
enabling agents to discover and execute tools from external MCP servers. MCP acts as a
"universal adapter" connecting OpenSearch agents to remote tool providers via a standardized protocol.

## Architecture

### Dual Role: MCP Client + MCP Server

1. **OpenSearch as MCP Client** — Agents connect *outward* to external MCP servers via
   "MCP connectors" (protocol: `mcp_sse` or `mcp_streamable_http`). The connector stores
   URL, credentials, and transport config. Trusted endpoints are allowlisted via regex
   (`plugins.ml_commons.trusted_connector_endpoints_regex`).

2. **OpenSearch as MCP Server** — OpenSearch itself exposes its built-in tools (SearchIndex,
   ListIndex, PPL, VectorDB, RAG, etc.) as an MCP Streamable HTTP server at
   `/_plugins/_ml/mcp`. External MCP clients can connect and invoke registered tools.
   APIs: Register, Update, List, Remove MCP tools.

### Transport Protocols
- **SSE** (Server-Sent Events) — original transport, connector param `sse_endpoint: "/sse"`
- **Streamable HTTP** — preferred as of 3.3 (SSE APIs removed), connector param `endpoint: "/mcp"`
- `stdio` is **not** supported

## Agent Types That Support MCP

MCP tools can only be used with:
- **Conversational agents** — multi-turn LLM agents with memory
- **Plan-execute-reflect agents** — autonomous planning agents

Flow agents and conversational-flow agents do NOT support MCP connectors.

## Built-in Tools (30+)

OpenSearch provides a rich set of native tools agents can use alongside MCP tools:
- Search: SearchIndexTool, VectorDBTool, NeuralSparseSearchTool, QueryPlanningTool
- Index ops: ListIndexTool, IndexMappingTool
- Analytics: SearchAlertsTool, SearchAnomalyDetectorsTool, SearchAnomalyResultsTool, SearchMonitorsTool
- ML: MLModelTool, ConnectorTool, AgentTool
- Data: PPLTool, LogPatternTool, DataDistributionTool
- Gen AI: RAGTool, VisualizationTool, WebSearchTool, ScratchpadTools

## How Agents Use MCP Tools

1. **Create MCP Connector** — `POST /_plugins/_ml/connectors/_create` with protocol, URL, credentials
2. **Register LLM Model** — any remote model (OpenAI, Bedrock, etc.) via connector
3. **Register Agent** — include `mcp_connectors` array in agent parameters, each with:
   - `mcp_connector_id` — the connector ID
   - `tool_filters` (optional) — regex array to select specific tools from the server
4. **Execute Agent** — `POST /_plugins/_ml/agents/<id>/_execute` with natural language query
5. Agent autonomously discovers available tools (both built-in and MCP), calls them as needed

### Tool Filtering

Agents can selectively expose MCP server tools using `tool_filters` — an array of Java regex
patterns. A tool is included if it matches any pattern. Omitting filters exposes all tools.

## Agentic Search Pipeline Integration

MCP tools integrate into OpenSearch's agentic search via search pipelines:
- `agentic_query_translator` request processor translates NL → DSL using the agent
- `agentic_context` response processor returns agent step summaries and generated DSL
- The agent orchestrates MCP tools, ListIndexTool, IndexMappingTool, and QueryPlanningTool
  in sequence to resolve complex queries

## Security Model

- MCP must be explicitly enabled: `plugins.ml_commons.mcp_connector_enabled: true`
- Trusted endpoints allowlisted via regex patterns
- Credentials stored in connector `credential` object, referenced via `${credential.*}` syntax
- Standard OpenSearch security (roles, permissions) applies to agent and connector APIs

## Relevance to Exposing Investigation Objects to Agents

OpenSearch's MCP integration pattern is directly relevant to exposing investigation objects:

1. **Tool-as-interface pattern** — Investigation objects (findings, alerts, detectors, correlations)
   can be exposed as MCP tools that agents discover and invoke dynamically
2. **Connector abstraction** — A single MCP connector can expose multiple investigation tools;
   `tool_filters` let agents see only relevant tools per context
3. **Agent orchestration** — Conversational/plan-execute-reflect agents can chain investigation
   tools with search tools to build complex investigative workflows
4. **Existing security analytics tools** — OpenSearch already has SearchAlertsTool,
   SearchAnomalyDetectorsTool, SearchAnomalyResultsTool, SearchMonitorsTool as built-in tools,
   demonstrating the pattern of exposing operational objects to agents
5. **Bidirectional MCP** — OpenSearch can both consume external MCP tools AND expose its own
   tools as an MCP server, enabling cross-system agent collaboration

## Key Source URLs

- MCP Overview: https://docs.opensearch.org/latest/ml-commons-plugin/agents-tools/mcp/index/
- MCP Connector Setup: https://docs.opensearch.org/latest/ml-commons-plugin/agents-tools/mcp/mcp-connector/
- MCP Server APIs: https://docs.opensearch.org/latest/ml-commons-plugin/api/mcp-server-apis/index/
- Agentic Search + MCP: https://docs.opensearch.org/latest/vector-search/ai-search/agentic-search/mcp-server/
- Agent Types: https://docs.opensearch.org/latest/ml-commons-plugin/agents-tools/agents/index/
- Tools Catalog: https://docs.opensearch.org/latest/ml-commons-plugin/agents-tools/tools/index/
