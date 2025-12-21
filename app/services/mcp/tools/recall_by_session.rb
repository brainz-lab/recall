module Mcp
  module Tools
    class RecallBySession < Base
      DESCRIPTION = "Get all logs for a specific session."

      SCHEMA = {
        type: "object",
        properties: {
          session_id: { type: "string", description: "Session ID" }
        },
        required: ["session_id"]
      }.freeze

      def call(args)
        query_logs("session:#{args[:session_id]}", limit: 500)
      end
    end
  end
end
