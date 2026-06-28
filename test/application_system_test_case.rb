require "test_helper"
require_relative "test_helpers/navigation_system_test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include NavigationSystemTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ]

  setup do
    Capybara.default_max_wait_time = 10
  end

  teardown do
    Capybara.reset_sessions!
  end
end
