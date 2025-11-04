# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'securerandom'

module MCPCli
  # Client for HTTP-based MCP servers
  class HTTPClient
    def initialize(url, headers = {}, protocol_version = '2025-06-18')
      @url = url
      @headers = headers
      @protocol_version = protocol_version
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

    def send_request(method, params)
      uri = URI(@url)
      message = {
        jsonrpc: '2.0',
        id: SecureRandom.uuid,
        method: method,
        params: params
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri.path.empty? ? '/' : uri.path)
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'text/event-stream, application/json'
      @headers.each do |key, value|
        request[key] = value
      end
      request.body = JSON.generate(message)

      response = http.request(request)
      unless response.code == '200'
        puts "Response headers: #{response.to_hash}" if ENV['DEBUG']
        puts "Response body: #{response.body}" if ENV['DEBUG']
        raise "HTTP error: #{response.code} #{response.message}"
      end

      parse_sse_response(response.body)
    end

    def parse_sse_response(body)
      lines = body.split("\n")
      result = nil
      error = nil

      lines.each do |line|
        next if line.strip.empty?

        next unless line.start_with?('data: ')

        data = line[6..]
        next if data == '[DONE]'

        begin
          json = JSON.parse(data)
          if json['error']
            error = json['error']
          elsif json['result']
            result = json['result']
          end
        rescue JSON::ParserError
          puts "Failed to parse SSE data: #{data}" if ENV['DEBUG']
        end
      end

      if error
        raise "MCP Error: #{error['message'] || error.to_s}"
      elsif result.nil?
        raise 'No result received from server'
      end

      result
    end

    def cleanup
      # Nothing to clean up for HTTP client
    end
  end
end
