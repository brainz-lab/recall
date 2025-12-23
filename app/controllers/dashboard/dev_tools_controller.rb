module Dashboard
  class DevToolsController < BaseController
    before_action :ensure_development!

    def show
      @stats = {
        projects: Project.count,
        log_entries: LogEntry.count,
        saved_searches: SavedSearch.count
      }
    end

    def clean_logs
      counts = {
        log_entries: LogEntry.delete_all
      }

      redirect_to dashboard_dev_tools_path, notice: "Cleaned #{counts[:log_entries]} log entries"
    end

    def clean_all
      counts = {
        log_entries: LogEntry.delete_all,
        saved_searches: SavedSearch.delete_all
      }

      redirect_to dashboard_dev_tools_path, notice: "Cleaned all data: #{counts.map { |k, v| "#{v} #{k}" }.join(', ')}"
    end

    private

    def ensure_development!
      unless Rails.env.development?
        redirect_to dashboard_root_path, alert: "Dev tools only available in development"
      end
    end
  end
end
