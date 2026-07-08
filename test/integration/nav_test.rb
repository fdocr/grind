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

  test "signed in menu shows dashboard and sign out" do
    sign_in_as(users(:player))
    get root_path
    assert_select "[data-testid=nav-menu-panel] a", text: "Dashboard"
    assert_select "[data-testid=nav-sign-out]", text: "Sign out"
    assert_select "[data-testid=nav-menu-panel] a", text: "Sign in", count: 0
  end

  test "admin menu includes users and courses links" do
    sign_in_as(users(:admin))
    get root_path
    assert_select "[data-testid=nav-menu-panel] a", text: "Users"
    assert_select "[data-testid=nav-menu-panel] a", text: "Courses"
    assert_select "[data-testid=nav-menu-panel] a[href='/jobs']", text: "Jobs"
  end

  test "native apps drop the web header for the bridge-driven menu" do
    get root_path, headers: { "HTTP_USER_AGENT" => "Grind/1.0 Hotwire Native iOS; Turbo Native iOS;" }
    assert_response :success
    # No web hamburger button (only rendered in the web header): the native nav
    # bar supplies it instead.
    assert_select "[data-testid=nav-menu-button]", count: 0
    # The menu panel + bridge controller stay in the DOM so the native button can
    # open the same menu, with the same links.
    assert_select "[data-controller~=menu-bridge]", count: 1
    assert_select "[data-testid=nav-menu-panel] [role=menuitem]", minimum: 1
  end

  test "viewport opts into cover in the browser but not inside the native apps" do
    get root_path
    assert_select "meta[name=viewport][content*=?]", "viewport-fit=cover", count: 1

    get root_path, headers: { "HTTP_USER_AGENT" => "Grind/1.0 Hotwire Native iOS; Turbo Native iOS;" }
    assert_select "meta[name=viewport][content*=?]", "viewport-fit=cover", count: 0
  end
end
