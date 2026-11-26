require "application_system_test_case"

class TurnstileGateTest < ApplicationSystemTestCase
  setup do
    @player = users(:player)
    @course = courses(:one)
  end

  test "sign in stays disabled until turnstile issues a token" do
    with_stubbed_turnstile do
      visit new_session_path

      assert_selector "button[disabled][aria-busy='true']", text: "Sign in"
      assert_text "Unlocks when the check is ready."
      assert_equal "ui-turnstile-spin", submit_spinner("Sign in")

      fill_in "Email", with: @player.email
      fill_in "Password", with: "password"
      submit_turnstile_form_without_token
      assert_still_on new_session_path, "Unlocks when the check is ready."

      page.execute_script("window.__turnstileOptions['before-interactive-callback']()")
      assert_text "Complete the check above to continue."
      assert_selector "button[disabled]", text: "Sign in"
      assert_equal "none", submit_spinner("Sign in")
      submit_turnstile_form_without_token
      assert_still_on new_session_path, "Complete the check above to continue."

      page.execute_script("window.__turnstileOptions.callback('stub-token')")
      assert_selector "[data-turnstile-state=ready]"
      assert_selector "button:not([disabled])", text: "Sign in"
      assert_equal "none", submit_spinner("Sign in")

      page.execute_script("window.__turnstileOptions['expired-callback']()")
      assert_selector "button[disabled][aria-busy='true']", text: "Sign in"
      assert_text "Unlocks when the check is ready."

      page.execute_script("window.__turnstileOptions.callback('stub-token')")
      assert_selector "button:not([disabled])", text: "Sign in"
      click_button "Sign in"

      assert_text "Signed in"
      assert_current_path root_path, wait: Capybara.default_max_wait_time
    end
  end

  test "start round in the course sheet stays disabled until turnstile succeeds" do
    with_stubbed_turnstile do
      visit root_path
      fill_in "q", with: @course.name
      click_button "Search"
      click_link @course.name

      assert_selector "button[disabled]", text: "Start round"
      assert_text "Unlocks when the check is ready."
      submit_turnstile_form_without_token
      sleep 1
      assert_selector "button[disabled]", text: "Start round"
      assert_no_text "Round stats"

      page.execute_script("window.__turnstileOptions.callback('stub-token')")
      assert_selector "button:not([disabled])", text: "Start round"
      click_button "Start round"

      assert_text "Round stats"
    end
  end

  private

    def with_stubbed_turnstile
      with_turnstile_site_key do
        install_turnstile_stub
        yield
      end
    end

    def install_turnstile_stub
      browser = page.driver.browser
      browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
        (() => {
          const render = (element, options) => {
            window.__turnstileOptions = options
            window.__turnstileRenders = (window.__turnstileRenders || 0) + 1
            const input = document.createElement("input")
            input.type = "hidden"
            input.name = "cf-turnstile-response"
            input.value = "stub-token"
            element.appendChild(input)
            return "stub-widget"
          }
          const api = {
            render,
            remove() {},
            reset() {},
            getResponse() { return "stub-token" }
          }
          Object.freeze(api)
          Object.defineProperty(window, "turnstile", {
            configurable: false,
            enumerable: true,
            writable: false,
            value: api
          })
        })()
      JS
    end

    def wait_for_turnstile_stub
      deadline = Time.current + Capybara.default_max_wait_time
      last = nil
      stable = 0

      loop do
        count = page.evaluate_script("window.__turnstileRenders || 0")
        if count.positive? && count == last
          stable += 1
          break if stable >= 3
        else
          stable = 0
          last = count
        end

        raise "Turnstile stub did not render" if Time.current >= deadline

        sleep 0.05
      end
    end

    def submit_spinner(label)
      page.evaluate_script(<<~JS)
        (function() {
          const button = Array.from(document.querySelectorAll("button[type='submit']"))
            .find((node) => node.textContent.includes(#{label.to_json}))
          if (!button) return null
          return getComputedStyle(button, "::before").animationName
        })()
      JS
    end

    def submit_turnstile_form_without_token
      wait_for_turnstile_stub
      page.execute_script(<<~JS)
        const form = document.querySelector("[data-controller~='turnstile']").closest("form")
        try { form.requestSubmit() } catch (error) {}
        try { form.submit() } catch (error) {}
      JS
    end

    def assert_still_on(path, status_text)
      # Give a missed guard time to navigate before deciding the submit was blocked.
      sleep 1
      assert_current_path path
      assert_text status_text
      assert_no_text "Signed in"
    end
end
