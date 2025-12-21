module Mcp
  module Tools
    class RecallErrors < Base
      DESCRIPTION = "Get error and fatal logs. Quick way to see what's broken."

      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", description: "Time range (default 1h)", default: "1h" },
          commit: { type: "string", description: "Filter by commit SHA" }
        }
      }.freeze

      def call(args)
        q = "level:error,fatal since:#{args[:since] || '1h'}"
        q += " commit:#{args[:commit]}" if args[:commit]
        query_logs(q)
      end
    end
  end
end
