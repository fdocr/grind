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
end
