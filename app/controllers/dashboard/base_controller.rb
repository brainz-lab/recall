module Dashboard
  class BaseController < ApplicationController
    before_action :set_transaction_organization

    layout "dashboard"

    private

    def set_transaction_organization
      return unless defined?(BrainzLab::PlatformClient::CurrentTransaction)

      tx = BrainzLab::PlatformClient::CurrentTransaction.get
      return unless tx

      tx[:organization_id] = session[:platform_organization_id]
    end
  end
end
