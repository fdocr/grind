require "application_system_test_case"

class NativeAppBannerSystemTest < ApplicationSystemTestCase
  APP_STORE_URL = "https://apps.apple.com/us/app/grind-golf/id6787446479"
  IPHONE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ], options: { name: :iphone_chrome } do |browser_options|
    browser_options.add_argument("--user-agent=#{IPHONE_UA}")
  end

  test "banner opens on a fresh iphone homepage landing and stays closed after dismiss" do
    visit root_path
    assert_turbo_ready
    assert_match "iPhone", page.evaluate_script("navigator.userAgent")

    assert_selector "[data-testid='native-app-banner']", text: "Best experience is in the iPhone app"
    assert_text "Browsers work too."
    assert_link "Get the app", href: APP_STORE_URL

    find("[data-testid='native-app-banner-dismiss']").click
    assert_no_selector "[data-testid='native-app-banner']"

    click_link "Learn more about these game improvement stats"
    assert_current_path about_path

    find("a.text-xl", text: "Grind", match: :one).click
    assert_current_path root_path
    assert_equal "/", page.evaluate_script("document.documentElement.dataset.landingPath")
    assert_equal "done", page.evaluate_script("document.documentElement.dataset.nativeAppBanner")
    assert_selector "[data-testid='native-app-banner']", visible: :hidden

    visit root_path
    assert_selector "[data-testid='native-app-banner']"
  end

  test "banner stays closed when the iphone homepage is not the fresh landing" do
    visit about_path
    assert_turbo_ready
    assert_no_selector "[data-testid='native-app-banner']", visible: :all

    find("a.text-xl", text: "Grind", match: :one).click
    assert_current_path root_path
    assert_equal "/about", page.evaluate_script("document.documentElement.dataset.landingPath")
    assert_equal "true", page.evaluate_script("document.documentElement.dataset.iosBrowser")
    assert_selector "[data-testid='native-app-banner']", visible: :hidden
  end

  private

    def assert_turbo_ready
      Timeout.timeout(Capybara.default_max_wait_time) do
        loop do
          ready = page.evaluate_script(<<~JS)
            typeof Turbo !== "undefined" && Turbo.session && Turbo.session.started
          JS
          break if ready

          sleep 0.05
        end
      end
    end
end

class NativeAppBannerAndroidSystemTest < ApplicationSystemTestCase
  ANDROID_UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.122 Mobile Safari/537.36"

  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ], options: { name: :android_chrome } do |browser_options|
    browser_options.add_argument("--user-agent=#{ANDROID_UA}")
  end

  test "android browsers do not see the app banner" do
    visit root_path

    assert_match "Android", page.evaluate_script("navigator.userAgent")
    assert_no_selector "[data-testid='native-app-banner']", visible: :all
  end
end
