require "test_helper"

class MyRoundsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get my_rounds_path
    assert_redirected_to new_session_path
  end

  test "lists finished rounds for signed in user" do
    sign_in_as(users(:player))
    get my_rounds_path

    assert_response :success
    assert_match rounds(:player_round).course.name, response.body
  end
end
