module Mcp
  module Tools
    class Base
      def initialize(project)
        @project = project
      end

      def call(args)
        raise NotImplementedError
      end

      protected

      def query_logs(q, limit: 100)
        parser = QueryParser.new(q).parse
        scope = @project.log_entries

        if parser.stats?
          { stats: parser.apply_stats(parser.apply(scope)) }
        else
          logs = parser.apply(scope).limit(limit)
          { logs: logs.as_json, count: logs.size }
        end
      end
    end
  end
end
