require "test_helper"

class RoundTest < ActiveSupport::TestCase
  setup do
    @course = courses(:one)
    build_eighteen_holes!(@course)
  end

  test "score to par calculates over under and even" do
    round = Round.new(
      course: @course,
      hole_scores: (1..18).index_with { { "gross" => 5, "putts" => 2 } },
      finished_at: Time.current
    )

    expected = @course.holes.sum { |hole| 5 - hole.par }
    assert_equal expected, round.score_to_par
  end

  test "requires all hole gross scores when finished" do
    round = Round.new(
      course: @course,
      hole_scores: { "1" => { "gross" => 4, "putts" => 2 } },
      finished_at: Time.current
    )

    assert_not round.valid?
    assert_includes round.errors[:hole_scores].join, "hole 2"
  end
end
