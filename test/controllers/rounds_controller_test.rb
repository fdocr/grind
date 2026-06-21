require "test_helper"

class RoundsControllerTest < ActionDispatch::IntegrationTest
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
        oop_tee_shots: 0, three_putts: 0, botched_up_downs: 0, inside_pw_9i: 0,
        started_at: 1.hour.ago.iso8601, tee: "white", hole_scores: hole_scores
      }
    }

    assert_equal "white", Round.last.tee
  end

  test "create finished round and show scorecard" do
    hole_scores = (1..18).each_with_object({}) do |number, scores|
      scores[number.to_s] = { gross: 4, putts: 2 }
    end

    assert_difference "Round.count", 1 do
      post course_rounds_path(@course), params: {
        round: {
          oop_tee_shots: 1,
          three_putts: 2,
          botched_up_downs: 0,
          inside_pw_9i: 0,
          started_at: 2.hours.ago.iso8601,
          hole_scores: hole_scores
        }
      }
    end

    round = Round.last
    assert_redirected_to round_path(round.token)
    follow_redirect!
    assert_match "Round complete", response.body
    assert_match format_score_to_par(round.score_to_par), response.body
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
            three_putts: 0,
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
          three_putts: 0,
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
