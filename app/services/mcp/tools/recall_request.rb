# frozen_string_literal: true

module Mcp
  module Tools
    class RecallRequest < Base
      DESCRIPTION = "Get all logs for a specific request."

      SCHEMA = {
        type: "object",
        properties: {
          request_id: { type: "string", description: "Request ID" }
        },
        required: ["request_id"]
      }.freeze

      def call(args)
        query_logs("request_id:#{args[:request_id]}", limit: 500)
      end
    end
  end
end
