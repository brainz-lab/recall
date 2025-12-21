module Mcp
  class Server
    TOOLS = {
      'recall_query' => Tools::RecallQuery,
      'recall_errors' => Tools::RecallErrors,
      'recall_stats' => Tools::RecallStats,
      'recall_by_session' => Tools::RecallBySession,
      'recall_new_session' => Tools::RecallNewSession,
      'recall_clear_session' => Tools::RecallClearSession,
    }.freeze

    def initialize(project)
      @project = project
    end

    def list_tools
      TOOLS.map do |name, klass|
        {
          name: name,
          description: klass::DESCRIPTION,
          inputSchema: klass::SCHEMA
        }
      end
    end

    def call_tool(name, arguments = {})
      tool_class = TOOLS[name]
      raise "Unknown tool: #{name}" unless tool_class

      tool_class.new(@project).call(arguments.symbolize_keys)
    end
  end
end
