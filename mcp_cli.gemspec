# frozen_string_literal: true

require_relative 'lib/mcp_cli/version'

Gem::Specification.new do |spec|
  spec.name = 'mcp_cli'
  spec.version = MCPCli::VERSION
  spec.authors = ['Josh Beckman']
  spec.email = ['josh@joshbeckman.org']

  spec.summary = 'CLI for Model Context Protocol servers'
  spec.description = 'Command-line interface for interacting with MCP (Model Context Protocol) servers. Supports stdio and HTTP transports.'
  spec.homepage = 'https://github.com/joshbeckman/mcp_cli'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/joshbeckman/mcp_cli'
  spec.metadata['documentation_uri'] = 'https://github.com/joshbeckman/mcp_cli#readme'
  spec.metadata['changelog_uri'] = 'https://github.com/joshbeckman/mcp_cli/blob/main/CHANGELOG.md'

  spec.files = Dir['lib/**/*', 'exe/*', 'README.md', 'LICENSE', 'CHANGELOG.md']
  spec.bindir = 'exe'
  spec.executables = ['mcp']
  spec.require_paths = ['lib']

  # No runtime dependencies - stdlib only!
end
