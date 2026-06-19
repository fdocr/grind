require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "manifest is served" do
    get pwa_manifest_path(format: :json)
    assert_response :success
    assert_match "Grind", response.body
  end

  test "service worker is served" do
    get pwa_service_worker_path(format: :js)
    assert_response :success
    assert_match "CACHE_NAME", response.body
  end
end
