require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create registers user, sends welcome email, and signs in" do
    assert_enqueued_emails 1 do
      assert_difference "User.count", 1 do
        post registration_path, params: {
          user: {
            email: "newplayer@example.com",
            password: "password",
            password_confirmation: "password"
          }
        }
      end
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert_equal "newplayer@example.com", User.last.email
  end

  test "create with invalid password re-renders form" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          email: "newplayer@example.com",
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create promotes allowlisted email to admin" do
    stub_method(User, :admin_emails, [ "owner@example.com" ]) do
      post registration_path, params: {
        user: {
          email: "owner@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert User.find_by!(email: "owner@example.com").admin?
  end

  test "redirects authenticated users away from sign up" do
    sign_in_as(users(:player))
    get new_registration_path
    assert_redirected_to root_path
  end
end
