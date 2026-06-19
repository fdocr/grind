require "test_helper"

class CourseImporterTest < ActiveSupport::TestCase
  test "imports courses and holes from yaml" do
    path = file_fixture("sample_courses.yml")
    assert_difference "Course.count", +1 do
      assert_difference "Hole.count", +2 do
        Grind::CourseImporter.import!(path)
      end
    end

    course = Course.find_by!(name: "Sample Links")
    assert_equal 2, course.holes.count
    assert_equal "120", course.tees.dig("white", "slope")
  end
end
