module Dashboard
  class BaseController < ApplicationController
    before_action :require_authenticated_session!
    before_action :set_transaction_organization

    layout "dashboard"

    private

    def require_authenticated_session!
      return if session[:platform_user_id].present?

      # In development, allow bypass with a dev session
      if Rails.env.local?
        session[:platform_user_id] ||= "dev_user"
        return
      end

      redirect_to "#{platform_external_url}/auth/sso?product=recall&return_to=#{CGI.escape(request.url)}",
                  allow_other_host: true
    end

    def current_organization_projects
      if session[:platform_organization_id].present?
        Project.where(platform_organization_id: session[:platform_organization_id])
      else
        Project.all
      end
    end
    helper_method :current_organization_projects

    def find_scoped_project(id)
      current_organization_projects.find(id)
    end

    def platform_external_url
      ENV.fetch("BRAINZLAB_PLATFORM_EXTERNAL_URL", "http://platform.localhost")
    end

    def set_transaction_organization
      return unless defined?(BrainzLab::PlatformClient::CurrentTransaction)

      tx = BrainzLab::PlatformClient::CurrentTransaction.get
      return unless tx

      tx[:organization_id] = session[:platform_organization_id]
    end
  end
end
