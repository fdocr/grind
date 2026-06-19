require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  test "index lists courses" do
    get root_path
    assert_response :success
    assert_match "Grind", response.body
    assert_match courses(:one).name, response.body
  end

  test "search filters courses" do
    get courses_path, params: { q: "Pebble" }
    assert_response :success
    assert_match courses(:two).name, response.body
    assert_no_match courses(:one).name, response.body
  end
end
