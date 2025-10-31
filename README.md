# MCP CLI

A zero-dependency command-line interface for interacting with [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) servers. MCP enables AI assistants to securely connect to local and remote resources through a standardized protocol.

Perfect for developers who need to:
- Test MCP server implementations
- Debug server responses
- Integrate MCP servers into scripts and workflows
- Explore available tools and resources

Supports both stdio and HTTP transports with automatic configuration discovery.

## Requirements

- Ruby 2.7 or higher
- RubyGems 3.0 or higher
- Compatible with macOS, Linux, and Windows

## Quick Start (No Installation)

The fastest way to use MCP CLI is with `gem exec` - no installation required:

```bash
gem exec mcp_cli list
gem exec mcp_cli tools my-server
gem exec mcp_cli call my-server my-tool --arg value
```

This is perfect for trying out the tool or using it in scripts without adding dependencies. [`gem exec` supports fast software](https://www.joshbeckman.org/blog/practicing/the-gem-exec-command-gives-me-hope-for-ruby-in-a-world-of-fast-software).

## Installation (Optional)

If you prefer to install the gem:

```bash
gem install mcp_cli
```

Then use it directly:

```bash
mcp list
mcp tools my-server
```

## Configuration

MCP CLI looks for server configurations in these locations (in order):

1. `~/.claude.json`
2. `~/.cursor/mcp.json`
3. `~/.vscode/mcp.json`

You can also specify a custom config file:

```bash
gem exec mcp_cli --mcp-config /path/to/config.json list
```

Or use shortcuts for default configs:

```bash
gem exec mcp_cli --mcp-config claude list
gem exec mcp_cli --mcp-config cursor list
gem exec mcp_cli --mcp-config vscode list
```

### Configuration Format

Your config file should follow this structure:

```json
{
  "mcpServers": {
    "my-server": {
      "type": "stdio",
      "command": "node",
      "args": ["/path/to/server.js"],
      "env": {
        "API_KEY": "your-key"
      }
    },
    "http-server": {
      "type": "http",
      "url": "https://example.com/mcp",
      "headers": {
        "Authorization": "Bearer token"
      }
    }
  }
}
```

## Usage

### List Available Servers

```bash
gem exec mcp_cli list
```

### List Tools

```bash
# List all tools on a server
gem exec mcp_cli tools my-server

# Show details for a specific tool
gem exec mcp_cli tools my-server search_all
```

### Call a Tool

```bash
# With JSON arguments
gem exec mcp_cli call my-server search_all '{"query": "example"}'

# With flag-style arguments
gem exec mcp_cli call my-server search_all --query example

# Boolean flags
gem exec mcp_cli call my-server sync --force
```

### List Prompts

```bash
gem exec mcp_cli prompts my-server
```

### Get a Prompt

```bash
gem exec mcp_cli prompt my-server explain '{"topic": "MCP servers"}'
```

### List Resources

```bash
gem exec mcp_cli resources my-server
```

### Server Information

```bash
# Full server info
gem exec mcp_cli info my-server

# Just the version
gem exec mcp_cli version my-server

# Show configuration
gem exec mcp_cli config my-server
```

### Options

```bash
# Use a specific protocol version
gem exec mcp_cli --protocol-version 2025-06-18 tools my-server

# Use a custom config file
gem exec mcp_cli --mcp-config /path/to/config.json list

# Show help
gem exec mcp_cli --help

# Show version
gem exec mcp_cli --version
```

## Features

- **Zero dependencies** - Uses only Ruby standard library
- **Fast startup** - Minimal overhead for quick commands
- **Flexible arguments** - Supports both JSON and flag-style arguments
- **Multiple transports** - Works with stdio and HTTP MCP servers
- **Config auto-discovery** - Finds your existing MCP configurations

## Troubleshooting

### Server not found
Ensure your server name matches exactly what's in your config file. Server names are case-sensitive.

### Connection timeout
For stdio servers, verify the command path exists and is executable. Check that all required dependencies are installed.

### Authentication errors
Check that environment variables and headers are properly set in your config. For HTTP servers, ensure your authentication tokens are valid.

### No config file found
MCP CLI looks for configs in `~/.claude.json`, `~/.cursor/mcp.json`, or `~/.vscode/mcp.json`. Create one of these files or specify a custom path with `--mcp-config`.

## Development

```bash
# Clone the repo
git clone https://github.com/joshbeckman/mcp_cli.git
cd mcp_cli

# Install dependencies (just development tools)
bundle install

# Run tests
bundle exec rspec

# Test locally with gem exec
gem exec -g mcp_cli.gemspec mcp list
```

## License

MIT

## Contributing

Bug reports and pull requests welcome on GitHub at https://github.com/joshbeckman/mcp_cli.
