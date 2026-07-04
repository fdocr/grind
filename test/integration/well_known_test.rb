require "test_helper"

class WellKnownTest < ActionDispatch::IntegrationTest
  test "apple-app-site-association is served as JSON with the app id" do
    get "/.well-known/apple-app-site-association"
    assert_response :success
    assert_match "application/json", response.media_type

    json = JSON.parse(response.body)
    assert_equal "VTT2UAS7Q4.cr.fdo.grind", json.dig("applinks", "details", 0, "appID")
    assert_equal [ "/*" ], json.dig("applinks", "details", 0, "paths")
    assert_includes json.dig("webcredentials", "apps"), "VTT2UAS7Q4.cr.fdo.grind"
    assert_includes json.dig("activitycontinuation", "apps"), "VTT2UAS7Q4.cr.fdo.grind"
  end

  test "assetlinks.json is served with the android package name" do
    get "/.well-known/assetlinks.json"
    assert_response :success
    assert_match "application/json", response.media_type

    json = JSON.parse(response.body)
    assert_equal "android_app", json.dig(0, "target", "namespace")
    assert_equal "cr.fdo.grind", json.dig(0, "target", "package_name")
    assert_includes json.dig(0, "relation"), "delegate_permission/common.handle_all_urls"
  end
end
