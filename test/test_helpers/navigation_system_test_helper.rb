module NavigationSystemTestHelper
  # Capybara matchers retry until the timeout. Prefer positive, user-visible
  # state (aria-expanded, visible panel) over class names toggled by Stimulus.
  def assert_javascript_ready
    assert_selector "[data-controller='nav-menu']", wait: Capybara.default_max_wait_time

    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        ready = page.evaluate_script(<<~JS)
          (function() {
            if (typeof window.Stimulus === "undefined") return false;
            const root = document.querySelector("[data-controller='nav-menu']");
            if (!root) return false;
            return Boolean(
              window.Stimulus.getControllerForElementAndIdentifier(root, "nav-menu")
            );
          })()
        JS
        break if ready

        sleep 0.05
      end
    end
  end

  def open_nav_menu
    assert_javascript_ready

    2.times do
      menu_button = find("[data-testid='nav-menu-button']")
      break if menu_button["aria-expanded"] == "true"

      menu_button.click
      break if has_selector?("[data-testid='nav-menu-button'][aria-expanded='true']", wait: 2)

      sleep 0.1
    end

    assert_selector "[data-testid='nav-menu-button'][aria-expanded='true']", wait: Capybara.default_max_wait_time
    assert_selector "[data-testid='nav-menu-panel']", visible: true, wait: Capybara.default_max_wait_time
  end

  def click_nav_link(href)
    open_nav_menu
    link = find("[data-testid='nav-menu-panel'] a[href='#{href}']", visible: true, wait: Capybara.default_max_wait_time)
    link.scroll_to(:center)
    link.click
  end

  def click_nav_sign_out
    open_nav_menu
    button = find("[data-testid='nav-sign-out']", visible: true, wait: Capybara.default_max_wait_time)
    button.scroll_to(:center)
    button.click
  end
end
