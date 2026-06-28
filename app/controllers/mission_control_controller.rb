# frozen_string_literal: true

class MissionControlController < ApplicationController
  require_authentication
  before_action :require_admin
  after_action :set_robots_header

  private

    def request_authentication
      session[:return_to_after_authenticating] = request.fullpath
      redirect_to main_app.new_session_path, alert: "Please sign in to continue."
    end

    def require_admin
      redirect_to main_app.root_path, alert: "Not authorized." unless current_user&.admin?
    end

    def set_robots_header
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
    end
end
