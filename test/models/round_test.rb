require "test_helper"

class RoundTest < ActiveSupport::TestCase
  setup do
    @course = courses(:one)
    build_eighteen_holes!(@course)
  end

  test "three putts counts holes with three or more putts" do
    round = Round.new(
      course: @course,
      hole_scores: {
        "1" => { "gross" => 4, "putts" => 2 },
        "2" => { "gross" => 5, "putts" => 3 },
        "3" => { "gross" => 4, "putts" => 4 },
        "4" => { "gross" => 5, "putts" => "" }
      }
    )

    assert_equal 2, round.three_putts
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

  test "valid finished round for nine hole course" do
    build_nine_holes!(@course)

    round = Round.new(
      course: @course,
      hole_scores: (1..9).index_with { |number| { "gross" => 4, "putts" => 2 } },
      finished_at: Time.current
    )

    assert round.valid?
  end

  test "nine hole course rejects missing back nine scores" do
    build_nine_holes!(@course)

    round = Round.new(
      course: @course,
      hole_scores: (1..8).index_with { |number| { "gross" => 4, "putts" => 2 } },
      finished_at: Time.current
    )

    assert_not round.valid?
    assert_includes round.errors[:hole_scores].join, "hole 9"
    assert_not_includes round.errors[:hole_scores].join, "hole 10"
  end
end
