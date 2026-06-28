require "test_helper"

class RoundStatsMailerTest < ActionMailer::TestCase
  setup do
    @guest_delivery = deliveries(:one)
    @registered_delivery = deliveries(:registered)
    build_eighteen_holes!(@guest_delivery.course)
    build_eighteen_holes!(@registered_delivery.course)
  end

  test "guest stats email includes register CTA" do
    email = RoundStatsMailer.stats(@guest_delivery)
    body = email.html_part.body.decoded

    assert_equal [ "player@example.com" ], email.to
    assert_includes body, @guest_delivery.course.name
    assert_includes body, "Score to par"
    assert_includes body, "grind.fdo.cr"
    assert_includes body, "utm_campaign=register"
    assert_includes body, 'href="https://ugo.cr/7kG34"'
  end

  test "registered user stats email excludes register CTA" do
    email = RoundStatsMailer.stats(@registered_delivery)
    html = email.html_part.body.decoded
    text = email.text_part.body.decoded

    assert_not_includes html, "utm_campaign=register"
    assert_not_includes text, "Create a free account"
  end
end
