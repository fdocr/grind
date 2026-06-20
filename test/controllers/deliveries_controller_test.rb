require "test_helper"

class DeliveriesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @round = rounds(:finished)
    build_eighteen_holes!(@round.course)
  end

  test "creates delivery and enqueues email job" do
    assert_enqueued_with(job: SendRoundStatsJob) do
      post round_delivery_path(@round.token), params: { delivery: { email: "player@example.com" } }
    end

    assert_redirected_to round_path(@round.token)
    assert_equal "player@example.com", Delivery.last.email
  end

  test "success notice renders only inside flash banner" do
    post round_delivery_path(@round.token), params: { delivery: { email: "player@example.com" } }
    follow_redirect!

    assert_response :success
    assert_select "#flash .ui-banner-success", count: 1
    assert_select "#flash .ui-banner-success p", text: "Your round stats are on the way."
    assert_select "#flash h1", count: 0
    assert_select "main > .space-y-6 > header h1", text: @round.course.name, count: 1
  end
end
