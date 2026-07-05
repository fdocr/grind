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
    assert_select "meta[property='og:title'][content='Grind']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "link[rel='canonical'][href='http://example.com/']"
    assert_select "script[type='application/ld+json']"
  end

  test "about page includes seo metadata" do
    get about_path
    assert_response :success
    assert_select "title", text: "About"
    assert_select "meta[property='og:title'][content='About']"
    assert_select "link[rel='canonical'][href='http://example.com/about']"
  end

  test "privacy page covers data handling basics" do
    get privacy_path
    assert_response :success
    assert_match "Privacy", response.body
    assert_match "never sell", response.body
    assert_match "local storage", response.body
    assert_match "grind@fdo.cr", response.body
  end

  test "privacy page includes seo metadata" do
    get privacy_path
    assert_response :success
    assert_select "title", text: "Privacy"
    assert_select "meta[property='og:title'][content='Privacy']"
    assert_select "link[rel='canonical'][href='http://example.com/privacy']"
  end
end
