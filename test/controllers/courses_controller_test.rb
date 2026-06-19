require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  test "index lists featured courses without a search query" do
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

  test "search returns at most ten courses" do
    11.times do |index|
      Course.create!(
        name: "Searchable Club #{index}",
        country: "US",
        city: "Searchville#{index}",
        state_province: "California"
      )
    end

    get courses_path, params: { q: "Searchable" }
    assert_response :success
    assert_select "a[href*='round']", count: 10
    assert_match "Refine your search", response.body
  end

  test "blank search shows recently played label when rounds exist" do
    get root_path
    assert_response :success
    assert_match "Recently played courses", response.body
  end
end
