module Mcp
  module Tools
    class RecallClearSession < Base
      DESCRIPTION = "Delete all logs for a session. Use to clean up and start fresh."

      SCHEMA = {
        type: "object",
        properties: {
          session_id: { type: "string", description: "Session ID to clear" }
        },
        required: ["session_id"]
      }.freeze

      def call(args)
        deleted = @project.log_entries.where(session_id: args[:session_id]).delete_all
        { deleted: deleted, session_id: args[:session_id] }
      end
    end
  end
end
