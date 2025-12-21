module Mcp
  module Tools
    class RecallQuery < Base
      DESCRIPTION = "Query logs using Recall Query Language. " \
        "Syntax: [text] [field:value]... [| command]. " \
        "Fields: level, env, commit, branch, since, data.* " \
        "Examples: 'level:error since:1h', 'data.user.id:123 level:error'"

      SCHEMA = {
        type: "object",
        properties: {
          query: { type: "string", description: "Query in Recall Query Language" },
          limit: { type: "integer", description: "Max results (default 100)", default: 100 }
        },
        required: ["query"]
      }.freeze

      def call(args)
        query_logs(args[:query], limit: args[:limit] || 100)
      end
    end
  end
end
