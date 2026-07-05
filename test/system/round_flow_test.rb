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
    visit round_course_path(@course)

    click_button "Post Score"
    find("[data-round-target='puttsPicker'] [data-value='3']").click
    click_button "Save"

    assert_text "Hole 2"

    assert_equal "1", find("[data-round-target='threePutts']").text

    find("[data-stat='oopTeeShots'][data-action*='increment']").click
    assert_text "Hole 2"

    click_button "Reset round"
    assert_text "Reset round?"
    click_button "Cancel"
    assert_text "Hole 2"

    click_button "Reset round"
    find("[data-action='round#confirmReset']").click

    assert_text "Hole 1"
    assert_text "Even"
    assert_equal "0", find("[data-round-target='threePutts']").text
    assert_no_selector "[data-round-target='statsLastHole']", visible: :visible
  end
end
