# frozen_string_literal: true

module Api
  module V1
    # Receives browser console logs from brainzlab-js SDK
    class BrowserController < BaseController
      skip_before_action :authenticate!, only: [:preflight, :create]
      before_action :set_cors_headers
      before_action :find_project_from_token, only: [:create]

      # OPTIONS /api/v1/browser (CORS preflight)
      def preflight
        head :ok
      end

      # POST /api/v1/browser
      # Receives browser console events from brainzlab-js SDK
      def create
        events = params[:events] || []
        context = params[:context] || {}
        accepted = 0

        unless @project
          render json: { error: "Project not found" }, status: :not_found
          return
        end

        events.each do |event|
          next unless event[:type] == "console"

          process_console_event(event, context)
          accepted += 1
        end

        render json: {
          status: "ok",
          session_id: request.headers["X-BrainzLab-Session"],
          accepted: accepted
        }
      rescue StandardError => e
        Rails.logger.error("[BrowserController] Error: #{e.message}")
        render json: { error: "Failed to process events" }, status: :unprocessable_entity
      end

      private

      def process_console_event(event, context)
        data = event[:data] || {}
        trace_ctx = extract_trace_context

        log_data = {
          source: "browser",
          url: event[:url],
          user_agent: event[:userAgent],
          arguments: data[:args]
        }

        # Include trace context for correlation with server-side traces
        if trace_ctx
          log_data[:trace_id] = trace_ctx[:trace_id]
          log_data[:parent_span_id] = trace_ctx[:parent_span_id] || trace_ctx[:span_id]
        end

        # Also include trace info from event itself if present
        if event[:traceId]
          log_data[:trace_id] ||= event[:traceId]
          log_data[:browser_span_id] = event[:spanId]
          log_data[:parent_span_id] ||= event[:parentSpanId]
        end

        # Create a log entry from browser console
        LogEntry.create!(
          project: @project,
          level: map_console_level(data[:level]),
          message: data[:message],
          timestamp: event[:timestamp] ? Time.parse(event[:timestamp]) : Time.current,
          environment: context[:environment] || "production",
          service: context[:service] || "browser",
          commit: context[:release],
          session_id: event[:sessionId],
          request_id: event[:requestId],
          data: log_data
        )
      rescue StandardError => e
        Rails.logger.warn("[BrowserController] Failed to create log entry: #{e.message}")
      end

      def map_console_level(console_level)
        case console_level&.to_s&.downcase
        when "error" then "error"
        when "warn" then "warn"
        when "info" then "info"
        when "debug" then "debug"
        else "info"
        end
      end

      def find_project_from_token
        token = extract_browser_token
        return unless token

        # Accept ingest_key (preferred for browser) or api_key
        if token.start_with?("rcl_ingest_")
          @project = Project.find_by(ingest_key: token)
        elsif token.start_with?("rcl_api_")
          @project = Project.find_by(api_key: token)
          Rails.logger.warn("[BrowserController] API key used for browser endpoint - consider using ingest_key")
        else
          # Try to find by project_id from context
          project_id = params.dig(:context, :projectId)
          # no-op for now
        end
      end

      def extract_browser_token
        auth_header = request.headers["Authorization"]
        return auth_header.sub(/^Bearer\s+/, "") if auth_header&.start_with?("Bearer ")
        request.headers["X-API-Key"]
      end

      def set_cors_headers
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-API-Key, X-BrainzLab-Session, traceparent, tracestate"
        response.headers["Access-Control-Max-Age"] = "86400"
      end

      # Extract trace context from request (W3C Trace Context format or body)
      def extract_trace_context
        # Try traceparent header first (W3C Trace Context)
        traceparent = request.headers["traceparent"] || request.headers["HTTP_TRACEPARENT"]
        if traceparent
          parts = traceparent.split("-")
          if parts.length >= 4
            return {
              trace_id: parts[1],
              span_id: parts[2],
              sampled: (parts[3].to_i(16) & 0x01) == 1
            }
          end
        end

        # Fallback to body context
        context = params[:context] || {}
        if context[:traceId]
          return {
            trace_id: context[:traceId],
            parent_span_id: context[:parentSpanId],
            sampled: true
          }
        end

        nil
      end
    end
  end
end
