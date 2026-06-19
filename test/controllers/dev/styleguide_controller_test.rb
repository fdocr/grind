require "test_helper"

class StyleguideControllerTest < ActionDispatch::IntegrationTest
  test "styleguide returns not found outside development" do
    get dev_styleguide_path
    assert_response :not_found
  end

  test "styleguide renders in development" do
    with_rails_env("development") do
      get dev_styleguide_path
      assert_response :success
      assert_match "Grind styleguide", response.body
    end
  end

  private

  def with_rails_env(env)
    previous = Rails.env
    Rails.env = ActiveSupport::StringInquirer.new(env)
    yield
  ensure
    Rails.env = previous
  end
end
