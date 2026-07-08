require "test_helper"

class UserDeletedMailerTest < ActionMailer::TestCase
  test "deleted user notification emails grind with round stats" do
    user = users(:player)
    rounds = [ rounds(:player_round) ]

    email = UserDeletedMailer.deleted_user_notification(user: user, rounds: rounds)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "grind@fdo.cr" ], email.to
    assert_match "Deleted Grind user: #{user.email}", email.subject

    body = email.html_part.body.decoded
    assert_match user.email, body
    assert_match I18n.l(user.created_at, format: :long), body
    assert_match rounds(:player_round).course.name, body
    assert_match "OOP", body
    assert_match "Botched", body
    assert_match "PW/9i", body
  end
end
