require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email" do
    user = User.new(email: " DOWNCASED@EXAMPLE.COM ")
    assert_equal "downcased@example.com", user.email
  end

  test "promotes allowlisted email to admin on create" do
    stub_method(User, :admin_emails, [ "owner@example.com" ]) do
      user = User.create!(email: "owner@example.com", password: "password", password_confirmation: "password")
      assert user.admin?
    end
  end
end
