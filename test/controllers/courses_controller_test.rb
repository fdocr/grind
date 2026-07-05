require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.clear }

  test "index lists featured courses without a search query" do
    get root_path
    assert_response :success
    assert_match "Grind", response.body
    assert_match courses(:one).name, response.body
  end

  test "index includes features section" do
    get root_path
    assert_response :success
    assert_match "Track your round score", response.body
    assert_match "Game improvement stats", response.body
    assert_match "Rangefinder", response.body
    assert_match "Stats to your inbox", response.body
    assert_match "Keep every round logged", response.body
    assert_match "grind@fdo.cr", response.body
    assert_select "a[href=?]", about_path
    assert_select "a[href=?]", new_registration_path
    assert_no_match "sample_tracking.png", response.body
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
    assert_select "a[data-turbo-frame='course_modal']", count: Course::RESULT_LIMIT
    assert_match "Refine your search", response.body
  end

  test "show renders the tee picker and scorecard popover" do
    course = courses(:one)
    build_eighteen_holes!(course)

    get course_path(course)
    assert_response :success
    assert_select "turbo-frame#course_modal"
    assert_match "data-tee-select-active-value=\"white\"", response.body
    assert_match "White tee", response.body
    assert_select "a[href*='round'][data-turbo-frame='_top'][data-action='click->modal#close']"
  end

  test "show renders a segmented control for multi-tee courses" do
    course = Course.create!(
      name: "Two Tee Club", country: "US", city: "Teeville", state_province: "California",
      tees: { "blue" => { "rating" => "72.1", "slope" => "130", "yardages" => Array.new(18, 400) },
              "white" => { "rating" => "70.0", "slope" => "125", "yardages" => Array.new(18, 360) } }
    )
    build_eighteen_holes!(course)

    get course_path(course)
    assert_response :success
    assert_select ".ui-segmented .ui-segmented-option", count: 2
  end

  test "show falls back to default tee for an unknown tee param" do
    course = courses(:one)
    build_eighteen_holes!(course)

    get course_path(course, tee: "purple")
    assert_response :success
    assert_match "White tee", response.body
  end

  test "blank search shows recently played label when rounds exist" do
    get root_path
    assert_response :success
    assert_match "Recently played courses", response.body
  end

  test "index is rate limited after fifteen requests in a minute" do
    15.times { get courses_path, params: { q: "Pebble" } }
    assert_response :success

    get courses_path, params: { q: "Pebble" }
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".ui-banner-danger", text: /Rate limit reached: Try again in a minute and slow down a bit/
  end

  test "index search is not rate limited for hotwire native requests" do
    headers = { "HTTP_USER_AGENT" => "Grind/1.0 Hotwire Native iOS; Turbo Native iOS;" }

    16.times { get courses_path, params: { q: "Pebble" }, headers: headers }
    assert_response :success
  end
end
