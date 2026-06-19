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
      fill_in "gross_score", with: "4"
      fill_in "putts", with: "2"
      click_button "Save"
      click_button "Next" unless index == 17
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
end
