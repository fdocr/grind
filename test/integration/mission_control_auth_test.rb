require "test_helper"

class MissionControlAuthTest < ActionDispatch::IntegrationTest
  test "jobs dashboard requires basic auth when credentials are set" do
    with_env(
      "MISSION_CONTROL_USERNAME" => "admin",
      "MISSION_CONTROL_PASSWORD" => "secret"
    ) do
      get "/jobs"
      assert_response :unauthorized
    end
  end

  test "jobs dashboard allows access with valid basic auth" do
    with_env(
      "MISSION_CONTROL_USERNAME" => "admin",
      "MISSION_CONTROL_PASSWORD" => "secret"
    ) do
      get "/jobs", headers: {
        "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret")
      }
      assert_response :success
    end
  end

  test "jobs dashboard is unavailable without credentials outside development" do
    with_env(
      "MISSION_CONTROL_USERNAME" => nil,
      "MISSION_CONTROL_PASSWORD" => nil
    ) do
      get "/jobs"
      assert_response :service_unavailable
    end
  end

  private

  def with_env(vars)
    original = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
