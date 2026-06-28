require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  setup do
    @player = users(:player)
    build_eighteen_holes!(@player.rounds.first.course) if @player.rounds.any?
  end

  test "sign in, visit my rounds via menu, and sign out via menu" do
    visit new_session_path

    fill_in "Email", with: @player.email
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_text "Signed in"

    open_nav_menu
    within(".ui-nav-menu-panel") do
      click_link "My Rounds"
    end

    assert_current_path my_rounds_path
    assert_text "My Rounds"

    open_nav_menu
    within(".ui-nav-menu-panel") do
      click_button "Sign out"
    end

    assert_text "Signed out"
    open_nav_menu
    assert_selector ".ui-nav-menu-panel a", text: "Sign in"
    assert_no_selector ".ui-nav-menu-panel a", text: "My Rounds"
  end

  private

    def open_nav_menu
      menu = find("button[name=menu]")
      menu.click

      panel = find(".ui-nav-menu-panel", visible: :all)
      assert panel.visible?, "expected navigation menu to open after clicking the menu button"
    end
end
