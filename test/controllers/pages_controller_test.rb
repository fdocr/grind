require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "about page explains the tracked stats" do
    get about_path
    assert_response :success
    assert_match "About Grind", response.body
    assert_match "OOP Tee Shots", response.body
    assert_match "Botched Up/Down", response.body
    assert_match "Inside PW/9i", response.body
    assert_match "inside pitching-wedge", response.body
    assert_select "a[href='https://github.com/fdocr/grind']"
  end

  test "homepage links to the about page and github" do
    get root_path
    assert_response :success
    assert_select "a[href='/about']"
    assert_select "a[href='https://github.com/fdocr/grind']"
    assert_no_match(/<h1[^>]*>Grind<\/h1>/, response.body)
  end
end
