require "test_helper"

class NativeAppBannerTest < ActionDispatch::IntegrationTest
  APP_STORE_URL = "https://apps.apple.com/us/app/grind-golf/id6787446479"
  IPHONE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
  IPAD_UA = "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
  MAC_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
  ANDROID_UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.122 Mobile Safari/537.36"

  test "iphone homepage renders a dismissible app banner" do
    get root_path, headers: { "HTTP_USER_AGENT" => IPHONE_UA }

    assert_response :success
    assert_select "script[data-native-app-banner-boot]", count: 1
    assert_select "[data-testid=native-app-banner].hidden[data-turbo-temporary]", count: 1
    assert_select "[data-testid=native-app-banner] img[src='/icon.svg']"
    assert_select "[data-testid=native-app-banner] p", text: "Best experience is in the iPhone app"
    assert_select "[data-testid=native-app-banner] p", text: "Browsers work too."
    assert_select "[data-testid=native-app-banner] a[href=?][data-turbo=false]", APP_STORE_URL, text: "Get the app"
    assert_select "[data-testid=native-app-banner-dismiss][aria-label=Dismiss]"
    assert_select "script[data-native-app-banner-reveal]", count: 1
  end

  test "ipad homepage renders the app banner" do
    get root_path, headers: { "HTTP_USER_AGENT" => IPAD_UA }

    assert_response :success
    assert_select "[data-testid=native-app-banner]", count: 1
  end

  test "mac homepage includes the banner for ipad desktop mode to open" do
    get root_path, headers: { "HTTP_USER_AGENT" => MAC_UA }

    assert_response :success
    assert_select "[data-testid=native-app-banner].hidden", count: 1
  end

  test "android browsers do not get the homepage app banner" do
    get root_path, headers: { "HTTP_USER_AGENT" => ANDROID_UA }

    assert_response :success
    assert_select "[data-testid=native-app-banner]", count: 0
  end

  test "other desktop browsers do not get the homepage app banner" do
    get root_path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0.0.0 Safari/537.36" }

    assert_response :success
    assert_select "[data-testid=native-app-banner]", count: 0
  end

  test "native apps do not get the homepage app banner" do
    get root_path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) Grind/1.0 Hotwire Native iOS; Turbo Native iOS;" }

    assert_response :success
    assert_select "[data-testid=native-app-banner]", count: 0
  end

  test "other pages omit the app banner but still record the landing" do
    get about_path, headers: { "HTTP_USER_AGENT" => IPHONE_UA }

    assert_response :success
    assert_select "[data-testid=native-app-banner]", count: 0
    assert_select "script[data-native-app-banner-boot]", count: 1
  end

  test "course search is not the homepage banner" do
    get courses_path, params: { q: "Pebble" }, headers: { "HTTP_USER_AGENT" => IPHONE_UA }

    assert_response :success
    assert_select "[data-testid=native-app-banner]", count: 0
  end
end
