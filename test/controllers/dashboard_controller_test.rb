require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "show requires authentication" do
    get dashboard_path
    assert_redirected_to new_session_path
  end

  test "show renders dashboard for signed in user" do
    sign_in_as(users(:player))
    get dashboard_path

    assert_response :success
    assert_match users(:player).email, response.body
    assert_select "turbo-frame#dashboard-rounds[src=?]", dashboard_rounds_path
  end

  test "rounds requires authentication" do
    get dashboard_rounds_path
    assert_redirected_to new_session_path
  end

  test "rounds renders turbo frame with finished rounds" do
    sign_in_as(users(:player))
    get dashboard_rounds_path, headers: { "Turbo-Frame" => "dashboard-rounds" }

    assert_response :success
    assert_select "turbo-frame#dashboard-rounds"
    assert_match rounds(:player_round).course.name, response.body
  end

  test "rounds paginates finished rounds" do
    sign_in_as(users(:player))
    original = DashboardController::ROUNDS_PER_PAGE
    DashboardController.send(:remove_const, :ROUNDS_PER_PAGE)
    DashboardController.const_set(:ROUNDS_PER_PAGE, 1)

    Round.create!(
      course: courses(:two),
      user: users(:player),
      token: "playerroundtoken02",
      oop_tee_shots: 0,
      botched_up_downs: 0,
      inside_pw_9i: 0,
      started_at: Time.zone.parse("2026-06-21 10:00:00"),
      finished_at: Time.zone.parse("2026-06-21 14:00:00"),
      hole_scores: rounds(:player_round).hole_scores
    )

    get dashboard_rounds_path(page: 2), headers: { "Turbo-Frame" => "dashboard-rounds" }
    assert_response :success
    assert_select "a[data-turbo-frame='dashboard-rounds']", text: "Previous"
  ensure
    DashboardController.send(:remove_const, :ROUNDS_PER_PAGE)
    DashboardController.const_set(:ROUNDS_PER_PAGE, original)
  end

  test "my-rounds redirects to dashboard" do
    sign_in_as(users(:player))
    get "/my-rounds"

    assert_redirected_to dashboard_path
  end
end
