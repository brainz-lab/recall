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

    # POST /mcp/rpc - JSON-RPC style (for MCP protocol)
    def rpc
      server = Mcp::Server.new(@project)

      case params[:method]
      when 'tools/list'
        render json: { result: { tools: server.list_tools } }
      when 'tools/call'
        result = server.call_tool(params.dig(:params, :name), params.dig(:params, :arguments) || {})
        render json: { result: result }
      else
        render json: { error: { code: -32601, message: "Method not found" } }
      end
    end

    private

    def authenticate!
      key = request.headers['Authorization']&.sub(/^Bearer\s+/, '') ||
            request.headers['X-API-Key'] ||
            params[:api_key]

      @project = Project.find_by(api_key: key)
      render json: { error: 'Unauthorized' }, status: :unauthorized unless @project
    end

    def tool_params
      params.except(:controller, :action, :name, :api_key).permit!.to_h
    end
  end
end
