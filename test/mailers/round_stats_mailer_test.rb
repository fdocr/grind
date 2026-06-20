require "test_helper"

class RoundStatsMailerTest < ActionMailer::TestCase
  setup do
    @delivery = deliveries(:one)
    build_eighteen_holes!(@delivery.course)
  end

  test "stats email includes round summary without dash prose" do
    email = RoundStatsMailer.stats(@delivery)
    body = email.html_part.body.decoded

    assert_equal [ "player@example.com" ], email.to
    assert_includes body, @delivery.course.name
    assert_includes body, "Score to par"
    assert_includes body, "grind.fdo.cr"
    assert_includes body, 'href="https://ugo.cr/7kG34"'
  end
end
