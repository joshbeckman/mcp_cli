# frozen_string_literal: true

require 'json'
require 'open3'

module MCPCli
  # Client for stdio-based MCP servers
  class Client
    def initialize(command, args, env, protocol_version = '2025-06-18')
      @command = command
      @args = args || []
      @env = env
      @protocol_version = protocol_version
      @process = nil
      @reader_thread = nil
      @message_id = 0
      @pending_requests = {}
      @initialized = false
      @server_info = nil
    end

    def list_tools
      ensure_initialized
      response = send_request('tools/list', {})
      response['tools'] || []
    end

    def list_prompts
      ensure_initialized
      response = send_request('prompts/list', {})
      response['prompts'] || []
    end

    def list_resources
      ensure_initialized
      response = send_request('resources/list', {})
      response['resources'] || []
    end

    def call_tool(tool_name, arguments)
      ensure_initialized
      response = send_request('tools/call', {
                                name: tool_name,
                                arguments: arguments
                              })
      response['content'] || response
    end

    def get_prompt(prompt_name, arguments)
      ensure_initialized
      response = send_request('prompts/get', {
                                name: prompt_name,
                                arguments: arguments
                              })
      if response['messages']
        response['messages'].map { |msg| msg['content']['text'] || msg['content'] }.join("\n\n")
      else
        response
      end
    end

    def get_server_info
      ensure_initialized
      @server_info || {}
    end

    private

    def ensure_initialized
      return if @initialized

      start_process
      response = send_request('initialize', {
                                protocolVersion: @protocol_version,
                                capabilities: {
                                  roots: { listChanged: true },
                                  sampling: {}
                                },
                                clientInfo: {
                                  name: 'MCP CLI',
                                  version: MCPCli::VERSION
                                }
                              })

      @server_info = response['serverInfo'] if response['serverInfo']
      @initialized = true
    end

    def start_process
      cmd = [@command] + @args
      @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(@env, *cmd)

      @reader_thread = Thread.new do
        while (line = @stdout.gets)
          handle_message(JSON.parse(line))
        end
      rescue StandardError => e
        puts "Reader thread error: #{e.message}"
      end
    end

    def send_request(method, params)
      message_id = next_message_id
      message = {
        jsonrpc: '2.0',
        id: message_id,
        method: method,
        params: params
      }

      @stdin.puts(JSON.generate(message))
      @stdin.flush

      wait_for_response(message_id)
    end

    def handle_message(message)
      return unless message['id'] && @pending_requests[message['id']]

      @pending_requests[message['id']][:response] = message
      @pending_requests[message['id']][:condition].signal
    end

    def wait_for_response(message_id)
      mutex = Mutex.new
      condition = ConditionVariable.new
      @pending_requests[message_id] = { condition: condition, response: nil }

      mutex.synchronize do
        condition.wait(mutex, 30)
      end

      response = @pending_requests[message_id][:response]
      @pending_requests.delete(message_id)

      if response.nil?
        raise 'Timeout waiting for response'
      elsif response['error']
        raise "MCP Error: #{response['error']['message']}"
      end

      response['result']
    end

    def next_message_id
      @message_id += 1
    end

    def cleanup
      @reader_thread&.kill
      @stdin&.close
      @stdout&.close
      @stderr&.close
      @wait_thread&.kill
    end
  end
end
