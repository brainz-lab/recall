# frozen_string_literal: true

# Self-logging for Recall
# Uses direct database inserts to avoid HTTP infinite loops

# Middleware to capture request context for self-logging
class RecallSelfLogMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    Thread.current[:recall_request_id] = request.request_id
    Thread.current[:recall_session_id] = request.session.id.to_s rescue nil
    @app.call(env)
  ensure
    Thread.current[:recall_request_id] = nil
    Thread.current[:recall_session_id] = nil
  end
end

Rails.application.config.middleware.insert_after ActionDispatch::RequestId, RecallSelfLogMiddleware

Rails.application.config.after_initialize do
  # Find or create the recall project
  project = Project.find_or_create_by!(name: "recall") do |p|
    p.ingest_key = "rcl_ingest_#{SecureRandom.hex(16)}"
    p.api_key = "rcl_api_#{SecureRandom.hex(16)}"
  end

  Rails.logger.info "[Recall] Self-logging enabled for project: #{project.id}"

  # Subscribe to request completion events
  ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    payload = event.payload

    # Skip logging the ingest endpoints to avoid noise
    next if payload[:controller] == "Api::V1::IngestController"
    next if payload[:path]&.start_with?("/api/v1/log")

    # Extract request_id from headers or payload
    request_id = payload[:headers]&.env&.dig("action_dispatch.request_id") ||
                 payload[:request]&.request_id ||
                 Thread.current[:request_id]

    # Extract session_id if available
    session_id = payload[:request]&.session&.id&.to_s rescue nil

    begin
      LogEntry.create!(
        project: project,
        timestamp: Time.current,
        level: payload[:status].to_i >= 400 ? "error" : "info",
        message: "#{payload[:method]} #{payload[:path]}",
        service: "recall",
        environment: Rails.env,
        request_id: request_id,
        session_id: session_id,
        host: Socket.gethostname,
        data: {
          controller: payload[:controller],
          action: payload[:action],
          status: payload[:status],
          duration_ms: event.duration.round(1),
          view_ms: payload[:view_runtime]&.round(1),
          db_ms: payload[:db_runtime]&.round(1),
          format: payload[:format],
          params: payload[:params].except("controller", "action").to_h
        }
      )
    rescue StandardError => e
      Rails.logger.error "[Recall] Self-logging failed: #{e.message}"
    end
  end

  # Subscribe to ActiveJob events
  ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]

    begin
      LogEntry.create!(
        project: project,
        timestamp: Time.current,
        level: "info",
        message: "Job #{job.class.name}",
        service: "recall",
        environment: Rails.env,
        host: Socket.gethostname,
        data: {
          job_class: job.class.name,
          job_id: job.job_id,
          queue_name: job.queue_name,
          duration_ms: event.duration.round(1),
          executions: job.executions
        }
      )
    rescue StandardError => e
      Rails.logger.error "[Recall] Job logging failed: #{e.message}"
    end
  end

  # Subscribe to job errors
  ActiveSupport::Notifications.subscribe("discard.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]
    error = event.payload[:error]

    begin
      LogEntry.create!(
        project: project,
        timestamp: Time.current,
        level: "error",
        message: "Job failed: #{job.class.name} - #{error.class}: #{error.message}",
        service: "recall",
        environment: Rails.env,
        host: Socket.gethostname,
        data: {
          job_class: job.class.name,
          job_id: job.job_id,
          queue_name: job.queue_name,
          error_class: error.class.name,
          error_message: error.message,
          backtrace: error.backtrace&.first(10)
        }
      )
    rescue StandardError => e
      Rails.logger.error "[Recall] Job error logging failed: #{e.message}"
    end
  end
end
