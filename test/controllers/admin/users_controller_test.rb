require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get admin_users_path
    assert_redirected_to new_session_path
  end

  test "requires admin role" do
    sign_in_as(users(:player))
    get admin_users_path
    assert_redirected_to root_path
    assert_match "Not authorized", flash[:alert]
  end

  test "admin can list and search users" do
    sign_in_as(users(:admin))
    get admin_users_path, params: { q: "player" }

    assert_response :success
    assert_match users(:player).email, response.body
    assert_no_match users(:banned).email, response.body
  end

  test "admin user list paginates" do
    sign_in_as(users(:admin))
    original_limit = Pagy::OPTIONS[:limit]
    Pagy::OPTIONS[:limit] = 1

    get admin_users_path, params: { page: 2 }
    assert_response :success
    assert_match "Page 2 of", response.body
  ensure
    Pagy::OPTIONS[:limit] = original_limit
  end

  test "admin can view user and update role" do
    sign_in_as(users(:admin))
    user = users(:player)

    get admin_user_path(user)
    assert_response :success
    assert_match user.email, response.body

    patch admin_user_path(user), params: { user: { role: "banned" } }
    assert_redirected_to admin_user_path(user)
    assert user.reload.banned?
    assert_empty user.sessions
  end

  test "admin cannot change own role" do
    admin = users(:admin)
    sign_in_as(admin)

    patch admin_user_path(admin), params: { user: { role: "user" } }
    assert_redirected_to admin_user_path(admin)
    assert admin.reload.admin?
  end
end
