require "application_system_test_case"

class DistancesTest < ApplicationSystemTestCase
  setup do
    @course = courses(:one)
  end

  test "shows live green distances and toggles units" do
    start_course_round!(@course)
    page.execute_script("window.localStorage.clear()")
    visit round_course_path(@course)
    assert_text "Round stats"

    stub_geolocation(latitude: 9.981234, longitude: -84.156789, accuracy: 5)

    click_button "Distances"

    assert_selector "[data-distances-target='unitOption'][data-value='yds'][data-state='active']"
    assert_selector "[data-distances-target='center']", text: /\d/
    yards = find("[data-distances-target='center']").text.to_i

    find("[data-distances-target='unitOption'][data-value='m']").click
    assert_selector "[data-distances-target='unitOption'][data-value='m'][data-state='active']"
    meters = find("[data-distances-target='center']").text.to_i
    assert_operator meters, :<, yards
  end

  test "switches between numbers and map views" do
    start_course_round!(@course)
    assert_text "Round stats"

    stub_geolocation(latitude: 9.981234, longitude: -84.156789, accuracy: 5)

    click_button "Distances"

    assert_selector "[data-distances-target='numbers'][data-state='active']"
    assert_selector "[data-distances-target='viewOption'][data-value='numbers'][data-state='active']"

    find("[data-distances-target='viewOption'][data-value='map']").click

    assert_selector "[data-distances-target='viewOption'][data-value='map'][data-state='active']"
    assert_selector "[data-distances-target='map'][data-state='active']"
    assert_selector "[data-distances-target='numbers'][data-state='inactive']"
    assert_selector ".leaflet-container"
    assert_selector ".distance-map-rotator[data-fitted='true']"
    assert_selector "[data-distances-target='mapContainer'][data-has-pivot='false']"
    assert_selector "[data-distances-target='clearPivot']", visible: :hidden

    assert_js(<<~JS, "expected the distances map to finish loading")
      (() => {
        const el = document.querySelector("[data-controller~='distances']")
        const controller = window.Stimulus.getControllerForElementAndIdentifier(el, "distances")
        return Boolean(controller && controller.distanceMap && controller.distanceMap.map && controller.distanceMap.map._loaded)
      })()
    JS

    assert_js(<<~JS, "expected the hole to sit above the player on a vertical line")
      (() => {
        const el = document.querySelector("[data-controller~='distances']")
        const controller = window.Stimulus.getControllerForElementAndIdentifier(el, "distances")
        const distanceMap = controller && controller.distanceMap
        if (!distanceMap || !distanceMap.user || !distanceMap.green) return false

        const rotator = distanceMap.rotator
        if (!rotator || !rotator.style.transform.includes("rotate(")) return false

        const map = distanceMap.map
        const user = map.latLngToContainerPoint(distanceMap.user)
        const green = map.latLngToContainerPoint(distanceMap.green)
        if (user.distanceTo(green) < 30) return false
        const center = map.getSize().divideBy(2)
        const radians = distanceMap.headingDegrees * Math.PI / 180
        const rotate = (point) => {
          const x = point.x - center.x
          const y = point.y - center.y
          return {
            x: x * Math.cos(radians) - y * Math.sin(radians),
            y: x * Math.sin(radians) + y * Math.cos(radians)
          }
        }
        const screenUser = rotate(user)
        const screenGreen = rotate(green)
        const horizontal = Math.abs(screenGreen.x - screenUser.x)
        const vertical = screenUser.y - screenGreen.y
        return vertical > 0 && horizontal < vertical * 0.15
      })()
    JS

    page.execute_script(<<~JS)
      const el = document.querySelector("[data-controller~='distances']")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(el, "distances")
      controller.distanceMap.setPivot([9.9814, -84.1566], { notify: true })
    JS

    assert_selector "[data-distances-target='mapContainer'][data-has-pivot='true']"
    assert_selector "[data-distances-target='clearPivot']:not(.hidden)"

    find("[data-distances-target='clearPivot']").click
    assert_selector "[data-distances-target='mapContainer'][data-has-pivot='false']"
    assert_selector "[data-distances-target='clearPivot']", visible: :hidden
  end

  test "shows a too far message when away from the green" do
    start_course_round!(@course)
    assert_text "Round stats"

    stub_geolocation(latitude: 9.5, longitude: -84.0, accuracy: 5)

    click_button "Distances"

    assert_text "You're too far away from the hole"
    assert_selector "[data-distances-target='viewToggle']", visible: :hidden
  end

  test "shows an empty state for a hole without map data" do
    start_course_round!(@course)
    assert_text "Round stats"

    # Hole 2 has no green geometry in the fixtures.
    click_button "Holes"
    assert_text "Select hole"
    find("[data-hole-number='2']").click

    click_button "Distances"
    assert_text "No map data for this hole yet"
    assert_selector "[data-distances-target='viewToggle']", visible: :hidden
  end

  test "standalone distances shell reads green payload from localStorage" do
    # Autostart begins watching on connect, so grant location before the visit.
    grant_geolocation(latitude: 9.981234, longitude: -84.156789, accuracy: 5)

    visit root_path
    hole = @course.holes.find_by!(number: 1)
    page.execute_script(<<~JS)
      localStorage.setItem("grind:distancesPayload", JSON.stringify({
        green: #{hole.green_geometry.to_json},
        holeNumber: 1,
        holePar: #{hole.par},
        courseName: #{@course.name.to_json}
      }))
    JS

    visit distances_path
    assert_text "Distances"
    assert_selector "[data-distances-target='holeLabel']", text: "Hole 1 · Par #{hole.par}"
    assert_selector "[data-distances-target='center']", text: /\d/, wait: 5
  end

  test "native offline distances opens the in-page overlay instead of navigating" do
    browser = page.driver.browser
    browser.execute_cdp(
      "Network.setUserAgentOverride",
      userAgent: "Grind/1.0 Hotwire Native iOS; Turbo Native iOS; bridge-components: [geolocation menu]"
    )

    begin
      start_course_round!(@course)
      assert_text "Round stats"
      assert_selector "a[href='#{distances_path}']", text: "Distances"
      assert_selector "[data-round-target='distancesPanel']", visible: :hidden

      page.execute_script(<<~JS)
        Object.defineProperty(navigator, "onLine", { configurable: true, get: () => false })
      JS

      click_link "Distances"

      assert_no_current_path distances_path
      assert_selector "[data-round-target='distancesPanel']:not(.hidden)"
      # Native UA uses the geolocation bridge (no WKWebView GPS); without a real
      # bridge, Distances stays on the locating/status UI rather than yardages.
      assert_text(/Finding your location|Getting a better GPS|couldn't find your location|Location access needed/i)
    ensure
      browser.execute_cdp(
        "Network.setUserAgentOverride",
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      )
    end
  end

  private

  def assert_js(script, message = "expected JavaScript condition")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    loop do
      return if page.evaluate_script(script)

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      flunk message if elapsed >= Capybara.default_max_wait_time
      sleep 0.1
    end
  end

  def stub_geolocation(latitude:, longitude:, accuracy:)
    page.execute_script(<<~JS)
      navigator.geolocation.watchPosition = function (success) {
        success({ coords: { latitude: #{latitude}, longitude: #{longitude}, accuracy: #{accuracy} } })
        return 1
      }
      navigator.geolocation.clearWatch = function () {}
    JS
  end

  def grant_geolocation(latitude:, longitude:, accuracy:)
    visit root_path
    origin = page.current_host
    browser = page.driver.browser
    browser.execute_cdp(
      "Browser.grantPermissions",
      origin: origin,
      permissions: [ "geolocation" ]
    )
    browser.execute_cdp(
      "Emulation.setGeolocationOverride",
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy
    )
  end
end
