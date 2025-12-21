module Mcp
  module Tools
    class RecallStats < Base
      DESCRIPTION = "Get log statistics grouped by level, commit, hour, or day."

      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", description: "Time range (default 24h)", default: "24h" },
          by: { type: "string", description: "Group by: level, commit, hour, day" }
        }
      }.freeze

      def call(args)
        q = "since:#{args[:since] || '24h'} | stats"
        q += " by:#{args[:by]}" if args[:by]
        query_logs(q)
      end
    end
  end
end
