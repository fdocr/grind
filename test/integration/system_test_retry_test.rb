require "application_system_test_case"

class SystemTestRetryMechanismTest < ApplicationSystemTestCase
  class << self
    attr_accessor :attempts
  end

  test "retries failed attempts before passing" do
    self.class.attempts = (self.class.attempts || 0) + 1
    assert_equal 2, self.class.attempts
  end
end
