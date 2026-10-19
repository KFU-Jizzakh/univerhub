class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include Pagy::Method
  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    Rails.logger.warn "Authorization failed: #{Current.user&.id || 'guest'} tried to access #{request.method} #{request.path}"
    redirect_back fallback_location: root_path, alert: t("pundit.not_authorized")
  end

  def current_user
    Current.user
  end
  helper_method :current_user
end
