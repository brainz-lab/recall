module Mcp
  module Tools
    class RecallNewSession < Base
      DESCRIPTION = "Create a new session ID. Use this to start fresh logging context."

      SCHEMA = {
        type: "object",
        properties: {}
      }.freeze

      def call(_args)
        session_id = "sess_#{SecureRandom.hex(12)}"
        { session_id: session_id }
      end
    end
  end
end
