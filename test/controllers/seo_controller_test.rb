require "test_helper"

class SeoControllerTest < ActionDispatch::IntegrationTest
  test "robots.txt disallows private paths and links sitemap" do
    get "/robots.txt"
    assert_response :success
    assert_match "Disallow: /jobs", response.body
    assert_match "Disallow: /dev/", response.body
    assert_match "Disallow: /rounds/", response.body
    assert_match "Sitemap: http://example.com/sitemap.xml", response.body
  end

  test "sitemap lists public pages" do
    get "/sitemap.xml"
    assert_response :success
    assert_match "<loc>http://example.com/</loc>", response.body
    assert_match "<loc>http://example.com/about</loc>", response.body
    assert_match "<loc>http://example.com/privacy</loc>", response.body
    assert_match "<loc>http://example.com/contribute</loc>", response.body
  end
end
