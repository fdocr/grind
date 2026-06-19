require "test_helper"

class UiHelperTest < ActionView::TestCase
  include UiHelper

  test "icon helper renders svg partial" do
    html = icon("check", class: "w-4 h-4")
    assert_includes html, "<svg"
    assert_includes html, "w-4 h-4"
  end
end
