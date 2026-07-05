require "test_helper"

class RoundsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ScoreHelper

  setup do
    @course = courses(:one)
    build_eighteen_holes!(@course)
  end

  test "new tracker page renders" do
    get round_course_path(@course)
    assert_response :success
    assert_match @course.name, response.body
    assert_match "data-round-course-value", response.body
    assert_select "meta[name='robots'][content='noindex, nofollow']"
  end

  test "new tracker uses the requested tee" do
    get round_course_path(@course, tee: "white")
    assert_response :success
    assert_match "data-round-tee-value=\"white\"", response.body
    assert_match "White tee", response.body
  end

  test "new tracker falls back to the default tee for an unknown tee" do
    get round_course_path(@course, tee: "purple")
    assert_response :success
    assert_match "data-round-tee-value=\"white\"", response.body
  end

  test "create stores the selected tee" do
    hole_scores = (1..18).each_with_object({}) do |number, scores|
      scores[number.to_s] = { gross: 4, putts: 2 }
    end

    post course_rounds_path(@course), params: {
      round: {
        oop_tee_shots: 0, botched_up_downs: 0, inside_pw_9i: 0,
        started_at: 1.hour.ago.iso8601, tee: "white", hole_scores: hole_scores
      }
    }

    assert_equal "white", Round.last.tee
  end

  test "create finished round and show scorecard" do
    hole_scores = (1..18).each_with_object({}) do |number, scores|
      putts = [ 1, 2 ].include?(number) ? 3 : 2
      scores[number.to_s] = { gross: 4, putts: putts }
    end

    assert_difference "Round.count", 1 do
      post course_rounds_path(@course), params: {
        round: {
          oop_tee_shots: 1,
          botched_up_downs: 0,
          inside_pw_9i: 0,
          started_at: 2.hours.ago.iso8601,
          hole_scores: hole_scores
        }
      }
    end

    round = Round.last
    assert_equal 2, round.three_putts
    assert_redirected_to round_path(round.token)
    follow_redirect!
    assert_match "Round complete", response.body
    assert_match format_score_to_par(round.score_to_par), response.body
    assert_match "Email your stats", response.body
  end

  test "signed in user gets auto recap and sees banner instead of email form" do
    sign_in_as(users(:player))
    hole_scores = (1..18).each_with_object({}) do |number, scores|
      scores[number.to_s] = { gross: 4, putts: 2 }
    end

    assert_enqueued_with(job: SendRoundStatsJob) do
      post course_rounds_path(@course), params: {
        round: {
          oop_tee_shots: 0, botched_up_downs: 0, inside_pw_9i: 0,
          started_at: 1.hour.ago.iso8601, hole_scores: hole_scores
        }
      }
    end

    round = Round.last
    assert_equal users(:player), round.user
    assert_equal users(:player).email, round.deliveries.last.email

    assert_redirected_to round_path(round.token)
    follow_redirect!
    assert_match "recap of your round in your inbox soon", response.body
    assert_no_match "Email your stats", response.body
  end

  test "banned signed in user cannot finish a round" do
    sign_in_as(users(:banned))
    hole_scores = (1..18).each_with_object({}) do |number, scores|
      scores[number.to_s] = { gross: 4, putts: 2 }
    end

    assert_no_difference "Round.count" do
      post course_rounds_path(@course), params: {
        round: {
          oop_tee_shots: 0, botched_up_downs: 0, inside_pw_9i: 0,
          started_at: 1.hour.ago.iso8601, hole_scores: hole_scores
        }
      }
    end

    assert_redirected_to new_session_path
    assert_match "suspended", flash[:alert]
  end

  test "create renders friendly banner without losing data when save raises" do
    hole_scores = (1..18).each_with_object({}) do |number, scores|
      scores[number.to_s] = { gross: 4, putts: 2 }
    end

    Round.class_eval { alias_method :__orig_save, :save }
    Round.define_method(:save) { |*| raise StandardError, "boom" }

    begin
      assert_no_difference "Round.count" do
        post course_rounds_path(@course), params: {
          round: {
            oop_tee_shots: 0,
            botched_up_downs: 0,
            inside_pw_9i: 0,
            started_at: 1.hour.ago.iso8601,
            hole_scores: hole_scores
          }
        }
      end
    ensure
      Round.class_eval do
        alias_method :save, :__orig_save
        remove_method :__orig_save
      end
    end

    assert_response :unprocessable_entity
    assert_match "Something went wrong", response.body
    assert_match "data-round-course-value", response.body
  end

  test "create finished nine hole round" do
    build_nine_holes!(@course)

    hole_scores = (1..9).each_with_object({}) do |number, scores|
      scores[number.to_s] = { gross: 4, putts: 2 }
    end

    assert_difference "Round.count", 1 do
      post course_rounds_path(@course), params: {
        round: {
          oop_tee_shots: 0,
          botched_up_downs: 0,
          inside_pw_9i: 0,
          started_at: 1.hour.ago.iso8601,
          hole_scores: hole_scores
        }
      }
    end

    round = Round.last
    assert_redirected_to round_path(round.token)
    follow_redirect!
    assert_match "Round complete", response.body
    assert_no_match "Back nine", response.body
  end
end
