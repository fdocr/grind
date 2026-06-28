require "test_helper"

class NavTest < ActionDispatch::IntegrationTest
  test "layout includes hamburger menu" do
    get root_path
    assert_response :success
    assert_select "[data-testid=nav-menu-button][aria-label='Open menu']"
    assert_select "[data-testid=nav-menu-panel]"
  end

  test "signed out menu shows sign in and sign up" do
    get root_path
    assert_select "[data-testid=nav-menu-panel] a", text: "Sign in"
    assert_select "[data-testid=nav-menu-panel] a", text: "Sign up"
    assert_select "[data-testid=nav-sign-out]", count: 0
  end

  test "signed in menu shows my rounds and sign out" do
    sign_in_as(users(:player))
    get root_path
    assert_select "[data-testid=nav-menu-panel] a", text: "My Rounds"
    assert_select "[data-testid=nav-sign-out]", text: "Sign out"
    assert_select "[data-testid=nav-menu-panel] a", text: "Sign in", count: 0
  end

  test "admin menu includes admin link" do
    sign_in_as(users(:admin))
    get root_path
    assert_select "[data-testid=nav-menu-panel] a", text: "Admin"
  end
end
