class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from StandardError do |exception|
    BrainzLab::Reflex.capture(exception, context: {
      controller: self.class.name,
      action: action_name,
      request_id: request.request_id,
      path: request.path,
      method: request.method
    })
    BrainzLab::Signal.trigger("app.unhandled_error", severity: :critical, details: {
      error: exception.class.name,
      message: exception.message,
      request_id: request.request_id
    })
    raise exception
  end
end
