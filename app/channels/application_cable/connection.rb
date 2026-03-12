module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_id, :current_organization_id

    def connect
      self.current_user_id = find_verified_user
      self.current_organization_id = request.session[:platform_organization_id]
    end

    private

    def find_verified_user
      user_id = request.session[:platform_user_id]

      if user_id.present?
        user_id
      elsif Rails.env.development?
        "dev_user"
      else
        reject_unauthorized_connection
      end
    end
  end
end
