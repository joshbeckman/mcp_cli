# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'mcp_cli/version'
require_relative 'mcp_cli/client'
require_relative 'mcp_cli/http_client'

module MCPCli
  # Main CLI interface for MCP servers
  class CLI
    FILE_NAME = 'mcp'

    def initialize
      @commands = {
        'list' => method(:list_servers),
        'tools' => method(:list_tools),
        'prompts' => method(:list_prompts),
        'resources' => method(:list_resources),
        'call' => method(:call_tool),
        'prompt' => method(:call_prompt),
        'info' => method(:show_info),
        'version' => method(:show_version),
        'config' => method(:show_config)
      }
      @claude_config_path = File.expand_path('~/.claude.json')
      @cursor_config_path = File.expand_path('~/.cursor/mcp.json')
      @vscode_config_path = File.expand_path('~/.vscode/mcp.json')
      @mcp_config_path = nil
      @protocol_version = '2025-06-18'
    end

    def run(args)
      parsed_args = parse_args(args)

      if parsed_args[:version]
        show_self_version
        exit 0
      end

      if parsed_args[:help] || parsed_args[:command].nil?
        show_help
        exit 0
      end

      @mcp_config_path = parsed_args[:mcp_config] if parsed_args[:mcp_config]
      @protocol_version = parsed_args[:protocol_version]
      command = parsed_args[:command]

      if @commands.key?(command)
        @commands[command].call(parsed_args[:args])
      else
        puts "Unknown command: #{command}"
        show_help
        exit 1
      end
    rescue StandardError => e
      puts "Error: #{e.message}"
      exit 1
    end

    private

    def create_mcp_client(server_info)
      case server_info[:type]
      when 'stdio'
        env = ENV.to_h.merge(server_info[:env] || {})
        MCPCli::Client.new(server_info[:command], server_info[:args], env, @protocol_version)
      when 'streamable-http', 'http'
        MCPCli::HTTPClient.new(server_info[:url], server_info[:headers], @protocol_version)
      else
        raise "Unsupported server type: #{server_info[:type]}"
      end
    end

    def parse_args(args)
      result = { help: false, version: false, mcp_config: nil, protocol_version: '2025-06-18', command: nil, args: [] }
      remaining_args = []

      i = 0
      while i < args.length
        case args[i]
        when '--help', '-h'
          result[:help] = true
          return result
        when '--version', '-v'
          result[:version] = true
          return result
        when '--mcp-config'
          raise '--mcp-config requires a path argument' unless i + 1 < args.length

          result[:mcp_config] = args[i + 1]
          i += 1
        when '--protocol-version'
          raise '--protocol-version requires a version argument' unless i + 1 < args.length

          result[:protocol_version] = args[i + 1]
          i += 1

        else
          remaining_args << args[i]
        end
        i += 1
      end

      unless remaining_args.empty?
        result[:command] = remaining_args[0]
        result[:args] = remaining_args[1..] || []
      end

      result
    end

    def show_self_version
      puts "#{MCPCli::VERSION} (MCP CLI)"
    end

    def show_help
      puts <<~HELP
        MCP CLI #{MCPCli::VERSION} - Call MCP servers from the command line

        Usage:
          #{FILE_NAME} list                                 List available MCP servers
          #{FILE_NAME} tools <server_name> [tool_name]      List tools or show tool details
          #{FILE_NAME} prompts <server_name>                List prompts available on a server
          #{FILE_NAME} resources <server_name>              List resources available on a server
          #{FILE_NAME} call <server_name> <tool> [args]     Call a tool on a server (JSON or --flags)
          #{FILE_NAME} prompt <server_name> <prompt> [args] Get a prompt from a server
          #{FILE_NAME} info <server_name>                   Get detailed server information
          #{FILE_NAME} version <server_name>                Get server version only
          #{FILE_NAME} config <server_name>                 Show server configuration

        Options:
          --mcp-config <path>        Path to MCP configuration JSON file
                                     (defaults to first found: ~/.claude.json, ~/.cursor/mcp.json, ~/.vscode/mcp.json)
                                     (use 'claude', 'cursor', or 'vscode' to specify a default)
          --protocol-version <ver>   MCP protocol version (defaults to #{@protocol_version})

        Examples:
          #{FILE_NAME} list
          #{FILE_NAME} tools vault
          #{FILE_NAME} tools vault search_all
          #{FILE_NAME} prompts vault
          #{FILE_NAME} resources vault
          #{FILE_NAME} call vault search_all '{"query": "example"}'
          #{FILE_NAME} call vault search_all --query example
          #{FILE_NAME} prompt vault explain '{"topic": "MCP servers"}'
          #{FILE_NAME} info vault
          #{FILE_NAME} version vault
          #{FILE_NAME} config vault
          #{FILE_NAME} --protocol-version #{@protocol_version} tools vault
          #{FILE_NAME} --mcp-config /path/to/mcp.json tools vault
      HELP
    end

    def list_servers(_args)
      servers, config_path = load_mcp_servers_with_path

      if servers.empty?
        puts 'No MCP servers configured'
      else
        puts "Available MCP servers (from #{config_path}):"
        servers.each do |name, config|
          type = config['type'] || 'stdio'
          case type
          when 'stdio'
            cmd_display = [config['command'], *config['args']].join(' ')
            puts "  #{name}: #{cmd_display}"
          when 'streamable-http', 'http'
            puts "  #{name}: #{config['url']}"
          else
            puts "  #{name}: (#{type})"
          end
        end
      end
    end

    def list_tools(args)
      if args.empty?
        puts 'Error: Server name required'
        puts "Usage: #{FILE_NAME} tools <server_name> [tool_name]"
        exit 1
      end

      server_name = args[0]
      tool_name = args[1]

      servers = load_mcp_servers
      unless servers.key?(server_name)
        puts "Error: Server '#{server_name}' not found"
        exit 1
      end

      server_info = parse_server_config(server_name, servers[server_name])

      mcp_client = create_mcp_client(server_info)
      tools = mcp_client.list_tools

      if tools.empty?
        puts "No tools available on server '#{server_name}'"
      elsif tool_name
        # Show details for specific tool
        tool = tools.find { |t| t['name'] == tool_name }
        if tool.nil?
          puts "Error: Tool '#{tool_name}' not found on server '#{server_name}'"
          exit 1
        end

        puts "Tool: #{tool['name']}"
        puts "Server: #{server_name}"
        puts "\nDescription:"
        puts "  #{tool['description']}" if tool['description']

        if tool['inputSchema']
          puts "\nInput Schema:"
          puts JSON.pretty_generate(tool['inputSchema'])
        end
      else
        # List all tools
        puts "Tools available on '#{server_name}':"
        tools.each do |tool|
          puts "\n  #{tool['name']}"
          puts "    Description: #{tool['description']}" if tool['description']
          next unless tool['inputSchema'] && tool['inputSchema']['properties']

          puts '    Parameters:'
          tool['inputSchema']['properties'].each do |param, schema|
            required = tool['inputSchema']['required']&.include?(param) ? ' (required)' : ''
            puts "      - #{param}: #{schema['type']}#{required}"
            puts "        #{schema['description']}" if schema['description']
          end
        end
      end
    end

    def list_prompts(args)
      if args.empty?
        puts 'Error: Server name required'
        puts "Usage: #{FILE_NAME} prompts <server_name>"
        exit 1
      end

      server_name = args[0]
      servers = load_mcp_servers
      unless servers.key?(server_name)
        puts "Error: Server '#{server_name}' not found"
        exit 1
      end

      server_info = parse_server_config(server_name, servers[server_name])

      mcp_client = create_mcp_client(server_info)
      prompts = mcp_client.list_prompts

      if prompts.empty?
        puts "No prompts available on server '#{server_name}'"
      else
        puts "Prompts available on '#{server_name}':"
        prompts.each do |prompt|
          puts "\n  #{prompt['name']}"
          puts "    Description: #{prompt['description']}" if prompt['description']
          next unless prompt['arguments']

          puts '    Arguments:'
          prompt['arguments'].each do |arg|
            required = arg['required'] ? ' (required)' : ''
            puts "      - #{arg['name']}#{required}"
            puts "        #{arg['description']}" if arg['description']
          end
        end
      end
    end

    def list_resources(args)
      if args.empty?
        puts 'Error: Server name required'
        puts "Usage: #{FILE_NAME} resources <server_name>"
        exit 1
      end

      server_name = args[0]
      servers = load_mcp_servers
      unless servers.key?(server_name)
        puts "Error: Server '#{server_name}' not found"
        exit 1
      end

      server_info = parse_server_config(server_name, servers[server_name])

      mcp_client = create_mcp_client(server_info)
      resources = mcp_client.list_resources

      if resources.empty?
        puts "No resources available on server '#{server_name}'"
      else
        puts "Resources available on '#{server_name}':"
        resources.each do |resource|
          puts "\n  #{resource['uri']}"
          puts "    Name: #{resource['name']}" if resource['name']
          puts "    Description: #{resource['description']}" if resource['description']
          puts "    MIME type: #{resource['mimeType']}" if resource['mimeType']
        end
      end
    end

    def call_tool(args)
      if args.length < 2
        puts 'Error: Server name and tool name required'
        puts "Usage: #{FILE_NAME} call <server_name> <tool> [arguments]"
        puts "Arguments can be JSON: '{\"key\": \"value\"}'"
        puts "Or flags: --key value --key2 value2"
        exit 1
      end

      server_name = args[0]
      tool_name = args[1]
      remaining_args = args[2..]
      # Parse tool arguments - either JSON or flags
      tool_args = if remaining_args.empty?
        {}
      elsif remaining_args.length == 1 && remaining_args[0].start_with?('{')
        JSON.parse(remaining_args[0])
      else
        parse_tool_flags(remaining_args)
      end

      servers = load_mcp_servers
      unless servers.key?(server_name)
        puts "Error: Server '#{server_name}' not found"
        exit 1
      end

      server_info = parse_server_config(server_name, servers[server_name])

      mcp_client = create_mcp_client(server_info)
      result = mcp_client.call_tool(tool_name, tool_args)

      puts JSON.pretty_generate(result)
    end

    def call_prompt(args)
      if args.length < 2
        puts 'Error: Server name and prompt name required'
        puts "Usage: #{FILE_NAME} prompt <server_name> <prompt> [arguments_json]"
        exit 1
      end

      server_name = args[0]
      prompt_name = args[1]
      prompt_args = args[2] ? JSON.parse(args[2]) : {}

      servers = load_mcp_servers
      unless servers.key?(server_name)
        puts "Error: Server '#{server_name}' not found"
        exit 1
      end

      server_info = parse_server_config(server_name, servers[server_name])

      mcp_client = create_mcp_client(server_info)
      result = mcp_client.get_prompt(prompt_name, prompt_args)

      puts result
    end

    def show_info(args)
      if args.empty?
        puts 'Error: Server name required'
        puts "Usage: #{FILE_NAME} info <server_name>"
        exit 1
      end

      server_name = args[0]
      servers = load_mcp_servers
      unless servers.key?(server_name)
        puts "Error: Server '#{server_name}' not found"
        exit 1
      end

      server_config = parse_server_config(server_name, servers[server_name])

      mcp_client = create_mcp_client(server_config)
      server_info = mcp_client.get_server_info

      puts "Server: #{server_name}"
      puts "Name: #{server_info['name']}" if server_info['name']
      puts "Version: #{server_info['version']}" if server_info['version']
      puts "Description: #{server_info['description']}" if server_info['description']

      puts "Protocol Version: #{server_info['protocolVersion']}" if server_info['protocolVersion']

      return unless server_info['capabilities']

      puts "\nCapabilities:"
      server_info['capabilities'].each do |cap, value|
        puts "  #{cap}: #{value.inspect}"
      end
    end

    def show_version(args)
      if args.empty?
        puts 'Error: Server name required'
        puts "Usage: #{FILE_NAME} version <server_name>"
        exit 1
      end

      server_name = args[0]
      servers = load_mcp_servers
      unless servers.key?(server_name)
        puts "Error: Server '#{server_name}' not found"
        exit 1
      end

      server_info = parse_server_config(server_name, servers[server_name])

      mcp_client = create_mcp_client(server_info)
      server_info = mcp_client.get_server_info

      puts server_info['version'] || 'Version information not available'
    end

    def show_config(args)
      if args.empty?
        puts 'Error: Server name required'
        puts "Usage: #{FILE_NAME} config <server_name>"
        exit 1
      end

      server_name = args[0]
      servers = load_mcp_servers
      unless servers.key?(server_name)
        puts "Error: Server '#{server_name}' not found"
        exit 1
      end

      server_config = parse_server_config(server_name, servers[server_name])

      puts "Server: #{server_name}"
      puts "Type: #{server_config[:type]}"

      case server_config[:type]
      when 'stdio'
        puts "Command: #{server_config[:command]}"
        if server_config[:args] && !server_config[:args].empty?
          puts 'Args:'
          server_config[:args].each do |arg|
            puts "  - #{arg}"
          end
        end
        if server_config[:env] && !server_config[:env].empty?
          puts 'Environment:'
          server_config[:env].each do |key, value|
            puts "  #{key}: #{value}"
          end
        end
      when 'streamable-http', 'http'
        puts "URL: #{server_config[:url]}"
      end
    end

    def load_mcp_servers
      servers, _ = load_mcp_servers_with_path
      servers
    end

    def load_mcp_servers_with_path
      if @mcp_config_path
        config_path = case @mcp_config_path
                      when 'claude'
                        @claude_config_path
                      when 'cursor'
                        @cursor_config_path
                      when 'vscode'
                        @vscode_config_path
                      else
                        @mcp_config_path
                      end
        unless File.exist?(config_path)
          raise "MCP configuration file not found at #{config_path}"
        end
      else
        config_path = [@claude_config_path, @cursor_config_path, @vscode_config_path].find do |path|
          File.exist?(path)
        end

        unless config_path
          raise "No MCP configuration file found. Tried:\n  #{@claude_config_path}\n  #{@cursor_config_path}\n  #{@vscode_config_path}"
        end
      end

      config = JSON.parse(File.read(config_path))
      servers = config['mcpServers'] || config['servers'] || {}
      [servers, config_path]
    end

    def parse_server_config(name, config)
      type = config['type'] || 'stdio'

      case type
      when 'stdio', nil
        {
          name: name,
          type: type,
          command: config['command'],
          args: config['args'] || [],
          env: config['env'] || {}
        }
      when 'streamable-http', 'http'
        {
          name: name,
          type: type,
          url: config['url'],
          headers: config['headers'] || {},
        }
      else
        raise "Server '#{name}' has unsupported type: #{type}"
      end
    end

    def parse_tool_flags(args)
      result = {}
      i = 0
      while i < args.length
        arg = args[i]
        if arg.start_with?('--')
          key = arg[2..] # Remove '--' prefix
          # Check if there's a value following this flag
          if i + 1 < args.length && !args[i + 1].start_with?('--')
            # Next argument is the value
            value = args[i + 1]
            # Try to parse the value as JSON if it looks like JSON
            result[key] = if value =~ /^(\{|\[|true|false|null|\d+(\.\d+)?$)/
              begin
                JSON.parse(value)
              rescue JSON::ParserError
                value # If parsing fails, use as string
              end
            else
              value
            end
            i += 2
          else
            # Boolean flag without a value
            result[key] = true
            i += 1
          end
        else
          raise "Invalid argument: '#{arg}'. Arguments must be in --key value format or JSON."
        end
      end
      result
    end
  end
end
