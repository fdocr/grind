require "test_helper"

class BootTest < ActiveSupport::TestCase
  test "application boots" do
    assert_equal "Grind", Rails.application.class.module_parent_name
  end
end
