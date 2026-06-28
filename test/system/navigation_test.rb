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
    assert_current_path root_path

    open_nav_menu
    assert_selector ".ui-nav-menu-panel a[href='#{my_rounds_path}']", visible: true, wait: 5
    find(".ui-nav-menu-panel a[href='#{my_rounds_path}']").click

    assert_current_path my_rounds_path, wait: 5
    assert_text "My Rounds"

    open_nav_menu
    find(".ui-nav-menu-panel button", text: "Sign out").click

    assert_text "Signed out"
    assert_current_path root_path, wait: 5

    open_nav_menu
    assert_selector ".ui-nav-menu-panel a[href='#{new_session_path}']", visible: true
    assert_no_selector ".ui-nav-menu-panel a[href='#{my_rounds_path}']"
  end

  private

    def open_nav_menu
      find("button[name=menu]").click
      assert_no_selector ".ui-nav-menu-panel.hidden", wait: 5
    end
end
