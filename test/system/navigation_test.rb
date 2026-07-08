require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  setup do
    @player = users(:player)
    build_eighteen_holes!(@player.rounds.first.course) if @player.rounds.any?
  end

  test "sign in, visit dashboard via menu, and sign out via menu" do
    visit new_session_path
    assert_javascript_ready

    fill_in "Email", with: @player.email
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_text "Signed in"
    assert_current_path root_path, wait: Capybara.default_max_wait_time

    click_nav_link(dashboard_path)
    assert_current_path dashboard_path, wait: Capybara.default_max_wait_time
    assert_text "Dashboard"

    click_nav_sign_out
    assert_text "Signed out"
    assert_current_path root_path, wait: Capybara.default_max_wait_time

    open_nav_menu
    assert_selector "[data-testid='nav-menu-panel'] a[href='#{new_session_path}']", visible: true
    assert_no_selector "[data-testid='nav-menu-panel'] a[href='#{dashboard_path}']"
  end
end
