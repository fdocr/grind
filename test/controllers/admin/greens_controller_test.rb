# frozen_string_literal: true

require "test_helper"

class Admin::GreensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = courses(:one)
    build_eighteen_holes!(@course) unless @course.holes.count == 18
    @hole = @course.holes.find_by!(number: 1)
  end

  test "requires authentication" do
    get edit_admin_course_greens_path(@course)
    assert_redirected_to new_session_path
  end

  test "requires admin role" do
    sign_in_as(users(:player))
    get edit_admin_course_greens_path(@course)
    assert_redirected_to root_path
  end

  test "redirects when course has no coordinates" do
    course = Course.create!(name: "No Coords", country: "US", city: "X", state_province: "Y", tees: {})
    build_eighteen_holes!(course)

    sign_in_as(users(:admin))
    get edit_admin_course_greens_path(course)
    assert_redirected_to admin_course_path(course)
  end

  test "admin can open editor" do
    sign_in_as(users(:admin))
    get edit_admin_course_greens_path(@course)

    assert_response :success
    assert_match "Calibrate greens", response.body
    assert_match "data-controller=\"green-editor\"", response.body
  end

  test "admin can save manual calibration" do
    sign_in_as(users(:admin))
    polygon = [
      [ 9.98155, -84.15655 ], [ 9.98155, -84.15645 ], [ 9.98145, -84.15645 ], [ 9.98145, -84.15655 ]
    ]
    calibration = {
      "1" => {
        "polygon" => polygon,
        "bbox" => [ -84.157, 9.981, -84.156, 9.982 ],
        "zoom" => 18,
        "provider" => "esri"
      }
    }.to_json

    patch admin_course_greens_path(@course), params: { calibration: calibration }

    assert_redirected_to admin_course_path(@course)
    @hole.reload
    assert @hole.green_manual?
    assert @hole.green?
    assert_equal polygon, @hole.green_polygon
  end

  test "admin can clear a hole green" do
    @hole.update!(green_geometry: { "centroid" => [ 1, 2 ], "polygon" => [ [ 1, 2 ], [ 1, 3 ], [ 2, 3 ] ] }, green_source: "manual")
    sign_in_as(users(:admin))

    patch admin_course_greens_path(@course), params: { calibration: { "1" => { "clear" => true } }.to_json }

    assert_redirected_to admin_course_path(@course)
    assert_nil @hole.reload.green_geometry
    assert_nil @hole.green_source
  end
end
