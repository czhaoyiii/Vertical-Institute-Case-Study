class ApplicationController < ActionController::Base
  before_action :authenticate_staff!

  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  def authenticate_staff!
    authenticate_or_request_with_http_basic("Vertical Institute") do |u, p|
      ActiveSupport::SecurityUtils.secure_compare(u, ENV.fetch("ADMIN_USER", "admin")) &
      ActiveSupport::SecurityUtils.secure_compare(p, ENV.fetch("ADMIN_PASS", "vertical"))
    end
  end
end
