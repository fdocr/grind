# frozen_string_literal: true

class MissionControlController < ActionController::Base
  before_action :authenticate_mission_control!
  after_action :set_robots_header

  private

  def authenticate_mission_control!
    username, password = mission_control_credentials

    unless username && password
      head :service_unavailable
      return
    end

    authenticate_or_request_with_http_basic("Grind Jobs") do |given_username, given_password|
      ActiveSupport::SecurityUtils.secure_compare(given_username, username) &&
        ActiveSupport::SecurityUtils.secure_compare(given_password, password)
    end
  end

  def mission_control_credentials
    username = ENV["MISSION_CONTROL_USERNAME"].presence
    password = ENV["MISSION_CONTROL_PASSWORD"].presence
    return [ username, password ] if username && password

    return %w[development development] if Rails.env.development?

    [ nil, nil ]
  end

  def set_robots_header
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
