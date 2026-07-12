require "test_helper"

class CourseTest < ActiveSupport::TestCase
  test "search finds courses by name" do
    course = courses(:one)
    assert_includes Course.search("Cariari"), course
    assert_not_includes Course.search("Pebble"), course
  end

  test "total par sums holes" do
    course = courses(:one)
    assert_equal course.holes.sum(:par), course.total_par
  end

  test "near returns closer courses first" do
    nearby = courses(:one)
    far = courses(:two)

    results = Course.near(nearby.latitude, nearby.longitude, limit: 10)

    assert_equal nearby, results.first
    assert_includes results, nearby
    assert_not_includes results, far
  end

  test "near returns none for invalid coordinates" do
    assert_empty Course.near(999, 0)
    assert_empty Course.near(0, 999)
  end

  test "played_by returns the users finished courses most recent first" do
    player = users(:player)
    older = courses(:one)
    newer = courses(:two)

    Round.create!(
      course: older,
      user: player,
      token: "olderplayerround",
      hole_scores: rounds(:finished).hole_scores,
      finished_at: 2.days.ago
    )
    Round.create!(
      course: newer,
      user: player,
      token: "newerplayerround",
      hole_scores: rounds(:finished).hole_scores,
      finished_at: 1.hour.ago
    )

    assert_equal [ newer, older ], Course.played_by(player, limit: 10).to_a
  end

  test "played_by ignores other users rounds" do
    assert_includes Course.played_by(users(:player)), courses(:one)
    assert_empty Course.played_by(users(:admin))
  end

  test "greens_mapped reflects hole green geometry" do
    course = courses(:one)
    assert course.greens_mapped?

    course.holes.update_all(green_geometry: nil)
    course.holes.reset
    assert_not course.greens_mapped?
  end

  test "to_param uses public_id" do
    course = courses(:one)
    assert_equal course.public_id, course.to_param
    assert_equal course, Course.find_by_param!(course.public_id)
  end

  test "find_by_param! falls back to numeric id for legacy resume links" do
    course = courses(:one)
    assert_equal course, Course.find_by_param!(course.id.to_s)
  end

  test "find_by_param! raises for unknown params" do
    assert_raises(ActiveRecord::RecordNotFound) { Course.find_by_param!("missing-course") }
    assert_raises(ActiveRecord::RecordNotFound) { Course.find_by_param!("999999999") }
  end
end
