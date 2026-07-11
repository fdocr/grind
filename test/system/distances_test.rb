require "application_system_test_case"

class DistancesTest < ApplicationSystemTestCase
  setup do
    @course = courses(:one)
  end

  test "shows live green distances and toggles units" do
    visit round_course_path(@course)
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
    visit round_course_path(@course)
    assert_text "Round stats"

    stub_geolocation(latitude: 9.981234, longitude: -84.156789, accuracy: 5)

    click_button "Distances"

    assert_selector "[data-distances-target='numbers']:not(.hidden)"
    assert_selector "[data-distances-target='viewOption'][data-value='numbers'][data-state='active']"

    find("[data-distances-target='viewOption'][data-value='map']").click

    assert_selector "[data-distances-target='viewOption'][data-value='map'][data-state='active']"
    assert_selector "[data-distances-target='map']:not(.hidden)"
    assert_selector "[data-distances-target='numbers']", visible: :hidden
    assert_selector ".leaflet-container"
    assert_selector "[data-distances-target='clearPivot']", visible: :hidden

    assert page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("[data-controller~='distances']")
        const controller = window.Stimulus.getControllerForElementAndIdentifier(el, "distances")
        return Boolean(controller && controller.distanceMap && controller.distanceMap.map && controller.distanceMap.map._loaded)
      })()
    JS

    page.execute_script(<<~JS)
      const el = document.querySelector("[data-controller~='distances']")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(el, "distances")
      controller.distanceMap.setPivot([9.9814, -84.1566], { notify: true })
    JS

    assert_selector "[data-distances-target='clearPivot']:not(.hidden)"

    find("[data-distances-target='clearPivot']").click
    assert_selector "[data-distances-target='clearPivot']", visible: :hidden
  end

  test "shows a too far message when away from the green" do
    visit round_course_path(@course)
    assert_text "Round stats"

    stub_geolocation(latitude: 9.5, longitude: -84.0, accuracy: 5)

    click_button "Distances"

    assert_text "You're too far away from the hole"
    assert_selector "[data-distances-target='viewToggle']", visible: :hidden
  end

  test "shows an empty state for a hole without map data" do
    visit round_course_path(@course)
    assert_text "Round stats"

    # Hole 2 has no green geometry in the fixtures.
    click_button "Holes"
    assert_text "Select hole"
    find("[data-hole-number='2']").click

    click_button "Distances"
    assert_text "No map data for this hole yet"
    assert_selector "[data-distances-target='viewToggle']", visible: :hidden
  end

  private

  def stub_geolocation(latitude:, longitude:, accuracy:)
    page.execute_script(<<~JS)
      navigator.geolocation.watchPosition = function (success) {
        success({ coords: { latitude: #{latitude}, longitude: #{longitude}, accuracy: #{accuracy} } })
        return 1
      }
      navigator.geolocation.clearWatch = function () {}
    JS
  end
end
