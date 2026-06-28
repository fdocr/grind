# frozen_string_literal: true

require "test_helper"

class MissionControlAuthTest < ActionDispatch::IntegrationTest
  test "jobs dashboard requires sign in" do
    get "/jobs"
    assert_redirected_to "/session/new"
  end

  test "jobs dashboard requires admin role" do
    sign_in_as(users(:player))
    get "/jobs"
    assert_redirected_to "/"
    assert_match "Not authorized", flash[:alert]
  end

  test "jobs dashboard allows admin access" do
    sign_in_as(users(:admin))
    get "/jobs"
    assert_response :success
  end
end
