class LogsChannel < ApplicationCable::Channel
  # Live tail - streams new logs to the dashboard
  def subscribed
    project = Project.find(params[:project_id])
    stream_for project
  end

  def unsubscribed
    stop_all_streams
  end

  # Broadcast helpers for use throughout the application
  class << self
    def broadcast_log(project, log_entry)
      broadcast_to(project, {
        type: "log",
        log: log_entry.as_json
      })
    end

    def broadcast_session_cleared(project, session_id, deleted_count)
      broadcast_to(project, {
        type: "session_cleared",
        session_id: session_id,
        deleted_count: deleted_count
      })
    end

    def broadcast_saved_search_created(project, saved_search)
      broadcast_to(project, {
        type: "saved_search_created",
        saved_search: {
          id: saved_search.id,
          name: saved_search.name,
          query: saved_search.query
        }
      })
    end

    def broadcast_saved_search_deleted(project, saved_search_id)
      broadcast_to(project, {
        type: "saved_search_deleted",
        saved_search_id: saved_search_id
      })
    end
  end
end
