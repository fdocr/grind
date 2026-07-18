require "application_system_test_case"

class RoundFlowTest < ApplicationSystemTestCase
  setup do
    @course = courses(:one)
  end

  test "search course start round track stats and finish" do
    visit root_path
    assert_text "Grind"
    fill_in "q", with: @course.name
    click_button "Search"
    click_link @course.name

    assert_text "White tee", wait: 5
    click_on "Start round"

    assert_text @course.name
    assert_text "Round stats"

    18.times do |index|
      click_button "Post Score"
      if [ 0, 1 ].include?(index)
        find("[data-round-target='puttsPicker'] [data-value='3']").click
      end
      click_button "Save"
      assert_text "Update stats"
      click_button "Cancel"
      break if index == 17
    end

    assert_equal "2", find("[data-round-target='threePutts']").text

    click_button "Finish round"

    assert_text "Round complete"
    assert_text "Score to par"

    fill_in "Email", with: "player@example.com"
    send_button = find("button", text: "Send stats")
    send_button.scroll_to(:center)
    send_button.click

    assert_text "Your round stats are on the way"
  end

  test "reset round clears saved progress after confirmation" do
    start_course_round!(@course)

    click_button "Post Score"
    find("[data-round-target='puttsPicker'] [data-value='3']").click
    click_button "Save"
    assert_text "Update stats"
    find("[data-stat='oopTeeShots'][data-action*='incrementStat']").click
    click_button "Save"

    assert_text "2nd hole"
    assert_equal "1", find("[data-round-target='threePutts']").text
    assert_equal "1", find("[data-round-target='oopTeeShots']").text

    click_button "Reset round"
    assert_text "Reset round?"
    click_button "Cancel"
    assert_text "2nd hole"

    click_button "Reset round"
    find("[data-action='round#confirmReset']").click

    assert_text "1st hole"
    assert_text "Even"
    assert_equal "0", find("[data-round-target='threePutts']").text
    assert_equal "0", find("[data-round-target='oopTeeShots']").text
    assert_no_selector "[data-round-target='statsLastHole']", visible: :visible
  end

  test "hole picker shows a check icon for posted scores" do
    start_course_round!(@course)
    page.execute_script("window.localStorage.clear()")
    visit round_course_path(@course)

    click_button "Post Score"
    assert_text "Post score"
    click_button "Save"
    assert_text "Update stats"
    click_button "Cancel"

    click_button "Holes"

    scored = find("[data-hole-number='1']")
    unscored = find("[data-hole-number='2']")

    assert scored.has_css?("svg")
    assert_not unscored.has_css?("svg")
    assert_no_text "Score 4"
    assert_no_text "Open"
  end

  test "resume ongoing round from homepage after unlock expires" do
    start_course_round!(@course)

    click_button "Post Score"
    find("[data-round-target='puttsPicker'] [data-value='3']").click
    click_button "Save"
    assert_text "Update stats"
    click_button "Cancel"
    assert_text "2nd hole"
    assert_equal "1", find("[data-round-target='threePutts']").text

    visit root_path
    assert_text @course.name
    assert_text "1 hole scored"

    travel 3.hours

    visit root_path
    assert_text @course.name
    assert_text "1 hole scored"

    find("[aria-label^='Continue round']").click

    assert_text "Round stats"
    assert_text "2nd hole"
    assert_equal "1", find("[data-round-target='threePutts']").text
  end

  test "posting on the last hole wraps to hole 1 when it has no score" do
    start_course_round!(@course)

    click_button "Holes"
    find("[data-hole-number='18']").click

    click_button "Post Score"
    click_button "Save"
    assert_text "Update stats"
    click_button "Cancel"

    assert_text "1st hole"
  end

  test "posting on the last hole stays put when hole 1 already has a score" do
    start_course_round!(@course)

    click_button "Post Score"
    click_button "Save"
    assert_text "Update stats"
    click_button "Cancel"
    assert_text "2nd hole"

    click_button "Holes"
    find("[data-hole-number='18']").click

    click_button "Post Score"
    click_button "Save"
    assert_text "Update stats"
    click_button "Cancel"

    assert_text "18th hole"
  end

  test "stats are edited through the post-score modal and attributed to the scored hole" do
    start_course_round!(@course)

    click_button "Post Score"
    click_button "Save"

    assert_text "Update stats"
    assert_selector "[data-round-target='statsPanelHole']", text: "Hole 1"
    assert_text "2nd hole"

    find("[data-stat='oopTeeShots'][data-action*='incrementStat']").click
    click_button "Save"

    assert_no_selector "[data-round-target='statsPanel']:not(.hidden)"
    assert_equal "1", find("[data-round-target='oopTeeShots']").text
    assert_selector "[data-round-target='statsLastHole']", text: /1st hole/
    within("section", text: "Round stats") do
      assert_no_selector "button.ui-icon-btn"
    end
  end
end
