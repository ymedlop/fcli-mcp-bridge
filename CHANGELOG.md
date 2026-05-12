# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-05-12

### Added
- Initial release of the **Fortify CLI MCP Bridge** Docker image.
- Integration of **Fortify CLI (fcli)** with **Supergateway** to expose MCP over HTTP/SSE.
- Support for bridging STDIO-based MCP server to network-accessible endpoints.
- Configurable MCP module via `FCLI_MCP_MODULE` (default: `ssc`).
- Configurable port via `MCP_PORT` (default: `8000`).
- Persistent data directory support via `/fcli-data`.
- Health endpoint exposed at `/healthz`.

### Features
- Enables usage of Fortify CLI MCP capabilities from **remote/non-STDIO clients**.
- SSE endpoint exposed at `/sse`.
- Message endpoint exposed at `/message`.
- Compatible with containerized deployments (Docker, Kubernetes).

### Security
- Designed to run without embedding credentials in the image.
- Supports external authentication via mounted volumes or runtime configuration.

### Known Limitations
- Requires external authentication setup (e.g., `fcli ssc session login`).
- Limited to modules supported by `fcli util mcp-server`.
- Minimal runtime images (e.g., hardened images) may require additional dependencies (shell, Java).
