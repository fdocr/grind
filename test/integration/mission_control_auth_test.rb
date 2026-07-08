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

  test "jobs layout includes the same turbo-tracked assets as the main app" do
    sign_in_as(users(:admin))
    get "/jobs"

    assert_select "link[rel=stylesheet][data-turbo-track=reload][href*='tailwind']"
    assert_select "link[rel=stylesheet][data-turbo-track=reload][href*='app']"
    assert_select "link[rel=stylesheet][href*='mission_control/jobs/application']:not([data-turbo-track])"
  end
end
