# frozen_string_literal: true

# Self-logging and error tracking for Recall
# Uses direct database inserts for logging to avoid HTTP infinite loops
# Uses SDK for Reflex error tracking (with loop prevention)
#
# Set BRAINZLAB_SDK_ENABLED=false to disable SDK initialization
# Useful for running migrations before SDK is ready
#
# Set BRAINZLAB_LOCAL_DEV=true to enable cross-service integrations
# (Reflex error tracking, Pulse APM). Off by default to avoid double monitoring.

# Skip during asset precompilation or when explicitly disabled
return if ENV["BRAINZLAB_SDK_ENABLED"] == "false"
return if ENV["SECRET_KEY_BASE_DUMMY"].present?

# Cross-service integrations only enabled when BRAINZLAB_LOCAL_DEV=true
local_dev_mode = ENV["BRAINZLAB_LOCAL_DEV"] == "true"

# Configure BrainzLab SDK for Reflex error tracking and Pulse APM
BrainzLab.configure do |config|
  # App name for auto-provisioning
  config.app_name = "recall"

  # Disable Recall logging via SDK (we use direct DB inserts)
  config.recall_enabled = false

  # Enable Reflex error tracking (only in local dev mode)
  config.reflex_enabled = local_dev_mode
  config.reflex_url = ENV.fetch("REFLEX_URL", "http://reflex.localhost")
  config.reflex_master_key = ENV["REFLEX_MASTER_KEY"]

  # Enable Pulse APM (only in local dev mode)
  config.pulse_enabled = local_dev_mode
  config.pulse_url = ENV.fetch("PULSE_URL", "http://pulse.localhost")
  config.pulse_master_key = ENV["PULSE_MASTER_KEY"]
  config.pulse_buffer_size = 1 if Rails.env.development?  # Send immediately in dev

  # Exclude common Rails exceptions
  config.reflex_excluded_exceptions = [
    "ActionController::RoutingError",
    "ActionController::InvalidAuthenticityToken",
    "ActionController::UnknownFormat"
  ]

  # Service identification
  config.service = "recall"
  config.environment = Rails.env
end

# Middleware to capture request context for self-logging
class RecallSelfLogMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    Thread.current[:recall_request_id] = request.request_id
    Thread.current[:recall_session_id] = request.session.id.to_s.presence rescue nil
    @app.call(env)
  ensure
    Thread.current[:recall_request_id] = nil
    Thread.current[:recall_session_id] = nil
  end
end

Rails.application.config.middleware.insert_after ActionDispatch::Session::CookieStore, RecallSelfLogMiddleware

Rails.application.config.after_initialize do
  # Provision Reflex and Pulse projects only in local dev mode
  if local_dev_mode
    BrainzLab::Reflex.ensure_provisioned!
    BrainzLab::Pulse.ensure_provisioned!
  end

  # Find or create the recall project for self-logging
  project = Project.find_or_create_by!(name: "recall") do |p|
    p.ingest_key = "rcl_ingest_#{SecureRandom.hex(16)}"
    p.api_key = "rcl_api_#{SecureRandom.hex(16)}"
  end

  Rails.logger.info "[Recall] Self-logging enabled for project: #{project.id}"
  Rails.logger.info "[Recall] Local dev mode: #{local_dev_mode ? 'enabled' : 'disabled'}"
  Rails.logger.info "[Recall] Reflex error tracking: #{BrainzLab.configuration.reflex_enabled ? 'enabled' : 'disabled'}"
  Rails.logger.info "[Recall] Pulse APM: #{BrainzLab.configuration.pulse_enabled ? 'enabled' : 'disabled'}"

  # Subscribe to request completion events
  ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    payload = event.payload

    # Skip logging the ingest endpoints to avoid noise
    next if payload[:controller] == "Api::V1::IngestController"
    next if payload[:path]&.start_with?("/api/v1/log")

    # Get request context from middleware
    request_id = Thread.current[:recall_request_id]
    session_id = Thread.current[:recall_session_id]

    # Use without_capture to prevent infinite loops when logging fails
    BrainzLab::Reflex.without_capture do
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
  end

  # Subscribe to ActiveJob events
  ActiveSupport::Notifications.subscribe("perform.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]

    BrainzLab::Reflex.without_capture do
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
  end

  # Subscribe to job errors
  ActiveSupport::Notifications.subscribe("discard.active_job") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    job = event.payload[:job]
    error = event.payload[:error]

    BrainzLab::Reflex.without_capture do
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
end
