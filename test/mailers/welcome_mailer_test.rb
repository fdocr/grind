require "test_helper"

class WelcomeMailerTest < ActionMailer::TestCase
  test "welcome email" do
    user = users(:player)
    email = WelcomeMailer.welcome(user)

    assert_equal [ user.email ], email.to
    assert_equal "Welcome to Grind", email.subject
    assert_includes email.body.encoded, user.email
    assert_includes email.body.encoded, "/session/new"
  end
end
