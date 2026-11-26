require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:player) }

  test "new omits turnstile when it is not configured" do
    with_turnstile_site_key(nil) do
      get new_session_path

      assert_response :success
      assert_select "[data-controller=turnstile]", count: 0
      assert_select "script[src*='challenges.cloudflare.com/turnstile']", count: 0
    end
  end

  test "new keeps sign in locked until turnstile is ready" do
    with_turnstile_site_key do
      get new_session_path

      assert_response :success
      assert_select "[data-controller=turnstile][data-turnstile-state=pending]"
      assert_select "[data-turnstile-target=statusText]", text: "Unlocks when the check is ready."
      assert_select "script[src*='challenges.cloudflare.com/turnstile/v0/api.js']"
      assert_select "form button[type=submit][disabled]", count: 0
    end
  end

  test "create with valid credentials" do
    post session_path, params: { email: @user.email, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email: @user.email, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "create rejects banned user" do
    banned = users(:banned)
    post session_path, params: { email: banned.email, password: "password" }

    assert_redirected_to new_session_path
    assert_match "suspended", flash[:alert]
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
