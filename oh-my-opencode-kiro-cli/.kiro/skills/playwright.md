---
name: playwright
description: "MUST USE for any browser-related tasks. Browser automation via Playwright MCP - verification, browsing, scraping, testing, screenshots, PDF."
---
# Playwright Browser Automation

This skill provides browser automation capabilities via the Playwright MCP server.

## Quick start
- Uses `npx @playwright/mcp@latest` to launch the MCP server.
- Navigate, snapshot, interact, assert, and capture screenshots/PDF as needed.

## Good defaults
- Re-snapshot after navigation or DOM mutations.
- Prefer semantic locators before CSS/XPath; fall back to snapshot refs.
- Capture evidence (screenshots) for assertions.
