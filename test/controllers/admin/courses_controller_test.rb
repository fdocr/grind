require "test_helper"

class Admin::CoursesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @course = courses(:one)
    build_eighteen_holes!(@course) unless @course.holes.count == 18
  end

  test "requires authentication" do
    get admin_courses_path
    assert_redirected_to new_session_path
  end

  test "requires admin role" do
    sign_in_as(users(:player))
    get admin_courses_path
    assert_redirected_to root_path
    assert_match "Not authorized", flash[:alert]
  end

  test "admin can list and search courses" do
    sign_in_as(users(:admin))
    get admin_courses_path, params: { q: "cariari" }

    assert_response :success
    assert_match @course.name, response.body
    assert_no_match courses(:two).name, response.body
  end

  test "admin course list paginates" do
    sign_in_as(users(:admin))
    original_limit = Pagy::OPTIONS[:limit]
    Pagy::OPTIONS[:limit] = 1

    get admin_courses_path, params: { page: 2 }
    assert_response :success
    assert_match "Page 2 of", response.body
  ensure
    Pagy::OPTIONS[:limit] = original_limit
  end

  test "admin can view course with scorecard and map" do
    sign_in_as(users(:admin))
    get admin_course_path(@course)

    assert_response :success
    assert_match @course.name, response.body
    assert_match "Scorecard", response.body
    assert_match "openstreetmap.org", response.body
  end

  test "admin can create course" do
    sign_in_as(users(:admin))

    assert_difference "Course.count", 1 do
      post admin_courses_path, params: course_params(name: "New Links", city: "Testville", state_province: "CA")
    end

    course = Course.order(:id).last
    assert_redirected_to admin_course_path(course)
    assert_equal "New Links", course.name
    assert_equal 18, course.holes.count
    assert_enqueued_with(job: OsmCourseSyncJob, args: [ course.id ])
  end

  test "admin can update course and holes" do
    sign_in_as(users(:admin))
    hole = @course.holes.find_by!(number: 1)

    patch admin_course_path(@course), params: {
      course: {
        name: @course.name,
        country: @course.country,
        city: @course.city,
        state_province: @course.state_province,
        latitude: @course.latitude,
        longitude: @course.longitude,
        holes_attributes: {
          "0" => { id: hole.id, number: 1, par: 5, handicap: hole.handicap }
        },
        tees: @course.tees
      }
    }

    assert_redirected_to admin_course_path(@course)
    assert_equal 5, hole.reload.par
  end

  test "admin can queue osm sync" do
    sign_in_as(users(:admin))

    assert_enqueued_with(job: OsmCourseSyncJob, args: [ @course.id ]) do
      post sync_osm_admin_course_path(@course)
    end

    assert_redirected_to admin_course_path(@course)
    assert_match "sync queued", flash[:notice]
  end

  test "admin can delete course" do
    sign_in_as(users(:admin))
    course = Course.create!(
      name: "Temporary",
      country: "US",
      city: "Nowhere",
      state_province: "ZZ",
      tees: {}
    )

    assert_difference "Course.count", -1 do
      delete admin_course_path(course)
    end

    assert_redirected_to admin_courses_path
  end

  private

    def course_params(overrides = {})
      holes = (1..18).index_with do |number|
        { number: number, par: 4, handicap: number }
      end

      {
        course: {
          name: "Sample",
          country: "US",
          city: "Monterey",
          state_province: "CA",
          latitude: 36.5,
          longitude: -121.8,
          metric: false,
          holes_attributes: holes,
          tees: {
            white: {
              rating: "72.0",
              slope: "130",
              yardages: Array.new(18, 400)
            }
          }
        }.deep_merge(overrides)
      }
    end
end
