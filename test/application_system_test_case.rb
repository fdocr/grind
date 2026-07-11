require "test_helper"
require_relative "test_helpers/navigation_system_test_helper"
require_relative "test_helpers/round_unlock_test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include NavigationSystemTestHelper
  include RoundUnlockTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ]

  setup do
    Rails.cache.clear
    Capybara.default_max_wait_time = 10
  end

  teardown do
    Capybara.reset_sessions!
  end

  # System tests share cookies with integration-style posts via the app host.
  def start_course_round!(course, tee: nil)
    visit course_path(course)
    click_button "Start round"
    assert_text "Round stats"
  end
end
