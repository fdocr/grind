# Retries flaky system tests without adding a gem. Prepended onto Minitest::Test
# so only ActionDispatch::SystemTestCase examples are affected.
module SystemTestRetry
  MAX_RETRIES = ENV.fetch("SYSTEM_TEST_MAX_RETRIES", 3).to_i

  def run
    return super unless system_test?

    attempt = 0

    loop do
      super
      return Minitest::Result.from(self) if failures.empty? || skipped?

      attempt += 1
      break if attempt > MAX_RETRIES

      log_retry(attempt, failures.first)
      failures.clear
      reset_browser_state
    end

    log_exhausted_retries
    Minitest::Result.from(self)
  end

  private

    def system_test?
      is_a?(ActionDispatch::SystemTestCase)
    end

    def log_retry(attempt, failure)
      summary = failure.message.to_s.lines.first.to_s.strip
      warn "[system test retry #{attempt}/#{MAX_RETRIES}] #{self.class}##{name}: #{summary}"
    end

    def log_exhausted_retries
      warn "[system test failed after #{MAX_RETRIES} retries] #{self.class}##{name}"
    end

    def reset_browser_state
      Capybara.reset_sessions! if defined?(Capybara)
    end
end

Minitest::Test.prepend(SystemTestRetry)
