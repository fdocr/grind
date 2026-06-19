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

    assert_text @course.name
    assert_text "Round stats"

    18.times do |index|
      click_button "Post Score"
      click_button "Save"
      break if index == 17
    end

    2.times { find("[data-stat='threePutts'][data-action*='increment']").click }

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
    click_button "Save"

    assert_text "Hole 2"

    find("[data-stat='threePutts'][data-action*='increment']").click
    assert_equal "1", find("[data-round-target='threePutts']").text

    click_button "Reset round"
    assert_text "Reset round?"
    click_button "Cancel"
    assert_text "Hole 2"

    click_button "Reset round"
    find("[data-action='round#confirmReset']").click

    assert_text "Hole 1"
    assert_text "Even"
    assert_equal "0", find("[data-round-target='threePutts']").text
  end
end
