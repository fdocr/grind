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
end
