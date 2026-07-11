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

  test "featured returns courses ordered by most recent finished round" do
    older = courses(:one)
    newer = courses(:two)

    Round.create!(
      course: older,
      token: "olderround",
      hole_scores: rounds(:finished).hole_scores,
      finished_at: 2.days.ago
    )
    Round.create!(
      course: newer,
      token: "newerround",
      hole_scores: rounds(:finished).hole_scores,
      finished_at: 1.hour.ago
    )

    assert_equal [ newer, older ], Course.featured(10).first(2)
  end

  test "featured returns random courses when no finished rounds exist" do
    Round.update_all(finished_at: nil)
    featured = Course.featured(10)

    assert featured.any?
    assert featured.size <= Course::RESULT_LIMIT
    assert featured.all? { |course| course.is_a?(Course) }
  end

  test "greens_mapped reflects hole green geometry" do
    course = courses(:one)
    assert course.greens_mapped?

    course.holes.update_all(green_geometry: nil)
    course.holes.reset
    assert_not course.greens_mapped?
  end
end
