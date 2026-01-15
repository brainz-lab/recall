module Mcp
  class ToolsController < ActionController::API
    before_action :authenticate!

    # GET /mcp/tools - List available tools
    def index
      server = Mcp::Server.new(@project)
      render json: { tools: server.list_tools }
    end

    # POST /mcp/tools/:name - Call a tool
    def call
      server = Mcp::Server.new(@project)
      result = server.call_tool(params[:name], tool_params)
      render json: result
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /mcp/rpc - JSON-RPC protocol
    def rpc
      method = params[:method]
      params_data = params[:params] || {}

      case method
      when "initialize"
        server_version = (Rails.application.config.version rescue "1.0.0")
        render json: {
          jsonrpc: "2.0",
          id: params[:id],
          result: {
            protocolVersion: "2024-11-05",
            capabilities: {
              tools: { listChanged: false }
            },
            serverInfo: {
              name: "recall",
              version: server_version
            }
          }
        }
      when "notifications/initialized", "initialized"
        render json: { jsonrpc: "2.0", id: params[:id], result: {} }
      when "ping"
        render json: { jsonrpc: "2.0", id: params[:id], result: {} }
      when "tools/list"
        server = Mcp::Server.new(@project)
        render json: {
          jsonrpc: "2.0",
          id: params[:id],
          result: { tools: server.list_tools }
        }
      when "tools/call"
        server = Mcp::Server.new(@project)
        tool_name = params_data[:name]
        raw_args = params_data[:arguments] || {}
        arguments = raw_args.respond_to?(:permit!) ? raw_args.permit!.to_h : raw_args.to_h
        result = server.call_tool(tool_name, arguments)
        render json: {
          jsonrpc: "2.0",
          id: params[:id],
          result: { content: [ { type: "text", text: result.to_json } ] }
        }
      else
        render json: {
          jsonrpc: "2.0",
          id: params[:id],
          error: { code: -32601, message: "Unknown method: #{method}" }
        }, status: :bad_request
      end
    rescue => e
      render json: {
        jsonrpc: "2.0",
        id: params[:id],
        error: { code: -32603, message: e.message }
      }, status: :unprocessable_entity
    end

    private

    def authenticate!
      raw_key = extract_api_key
      validation = PlatformClient.validate_key(raw_key)

      unless validation.valid?
        render json: { error: validation.error || "Invalid API key" }, status: :unauthorized
        return
      end

      @project = PlatformClient.find_or_create_project(validation, raw_key)
    end

    def extract_api_key
      auth_header = request.headers["Authorization"]
      return auth_header.sub(/^Bearer\s+/, "") if auth_header&.start_with?("Bearer ")
      request.headers["X-API-Key"] || params[:api_key]
    end

    def tool_params
      params.except(:controller, :action, :name, :api_key).permit!.to_h
    end
  end
end
