# frozen_string_literal: true

class MissionControlController < ActionController::Base
  before_action :authenticate_mission_control!

  private

  def authenticate_mission_control!
    username = ENV["MISSION_CONTROL_USERNAME"]
    password = ENV["MISSION_CONTROL_PASSWORD"]
    return if username.blank? || password.blank?

    authenticate_or_request_with_http_basic do |given_username, given_password|
      ActiveSupport::SecurityUtils.secure_compare(given_username, username) &&
        ActiveSupport::SecurityUtils.secure_compare(given_password, password)
    end
  end
end
