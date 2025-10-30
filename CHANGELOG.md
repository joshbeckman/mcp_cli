# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-30

### Added
- Initial release of MCP CLI
- Support for stdio-based MCP servers
- Support for HTTP-based MCP servers
- Commands: list, tools, prompts, resources, call, prompt, info, version, config
- Auto-discovery of config files (~/.claude.json, ~/.cursor/mcp.json, ~/.vscode/mcp.json)
- Flexible argument parsing (JSON and flag-style)
- Zero runtime dependencies (stdlib only)
- Optimized for `gem exec` usage
