require "test_helper"

class UiCardComponentTest < ActionView::TestCase
  test "card partial renders" do
    html = render(inline: <<~ERB)
      <%= render "ui/card" do %>
        Content
      <% end %>
    ERB
    assert_includes html, "Content"
    assert_includes html, "rounded-lg"
  end
end
