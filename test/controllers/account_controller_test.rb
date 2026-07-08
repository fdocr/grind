require "test_helper"

class AccountControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:player) }

  test "edit password requires authentication" do
    get edit_account_password_path
    assert_redirected_to new_session_path
  end

  test "edit password renders form" do
    sign_in_as(@user)
    get edit_account_password_path

    assert_response :success
    assert_match "Change password", response.body
  end

  test "update password with valid current password" do
    sign_in_as(@user)

    patch update_account_password_path, params: {
      current_password: "password",
      password: "newpassword",
      password_confirmation: "newpassword"
    }

    assert_redirected_to dashboard_path
    assert_equal "Password updated successfully.", flash[:notice]
    assert @user.reload.authenticate("newpassword")
  end

  test "update password rejects incorrect current password" do
    sign_in_as(@user)

    patch update_account_password_path, params: {
      current_password: "wrong",
      password: "newpassword",
      password_confirmation: "newpassword"
    }

    assert_redirected_to edit_account_password_path
    assert_equal "Current password is incorrect.", flash[:alert]
  end
end
