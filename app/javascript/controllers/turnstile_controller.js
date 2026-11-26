import { Controller } from "@hotwired/stimulus"

// Explicit Turnstile rendering for Turbo Frame / modal portals.
// Implicit api.js scanning only runs on first page load, so widgets injected
// later (course sheet, Turbo visits) need turnstile.render() on connect.
//
// Submit controls stay disabled until the widget issues a token. A fast click
// or Enter before that used to post with no captcha and fail server-side.

const SUBMIT_SELECTOR = "button[type='submit'], input[type='submit']"

const STATUS = {
  pending: "Unlocks when the check is ready.",
  challenge: "Complete the check above to continue.",
  error: "Security check couldn't load. Refresh the page and try again.",
  timeout: "Security check timed out. Refresh the page and try again.",
  ready: "Security check complete."
}

document.addEventListener("submit", (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement) || !formHasPendingTurnstile(form)) return

  event.preventDefault()
  event.stopPropagation()
}, true)

function formHasPendingTurnstile(form) {
  return Array.from(form.querySelectorAll("[data-controller~='turnstile']")).some((widget) => {
    return widget.dataset.turnstileState !== "ready"
  })
}

// form.submit() does not fire a submit event and ignores disabled buttons.
// The inline script in the partial installs the same guard before this module
// loads; the expando is not restored from a Turbo snapshot, so connect()
// installs it again on the fresh nodes.
function guardFormSubmit(form) {
  if (!form || form.__turnstileSubmitGuarded) return

  form.__turnstileSubmitGuarded = true
  const nativeSubmit = form.submit.bind(form)
  form.submit = () => {
    if (formHasPendingTurnstile(form)) return
    nativeSubmit()
  }
}

export default class extends Controller {
  static targets = [ "widget", "status", "statusText" ]
  static values = {
    sitekey: String,
    size: { type: String, default: "flexible" },
    theme: { type: String, default: "auto" }
  }

  connect() {
    this.widgetId = null
    this.cancelled = false
    this.attempts = 0
    this.failureMessage = null
    this.form = this.element.closest("form")
    guardFormSubmit(this.form)
    this.hold("pending")
    this.renderWhenReady()
  }

  disconnect() {
    this.cancelled = true
    this.removeWidget()
    // Drop any token and leave the snapshot blocked. A restore reconnects
    // and renders a fresh widget before the form can be sent.
    this.hold("pending")
  }

  async renderWhenReady() {
    const turnstile = await this.waitForTurnstile()
    if (this.cancelled || !this.hasWidgetTarget) return

    if (!turnstile) {
      this.failureMessage = STATUS.error
      this.hold("error")
      return
    }

    // Parent modal portals synchronously in its connect (before children).
    // Defer one frame so a mid-move reconnect settles on document.body first.
    await new Promise((resolve) => requestAnimationFrame(resolve))
    if (this.cancelled || !this.hasWidgetTarget) return

    this.removeWidget()

    try {
      this.widgetId = turnstile.render(this.widgetTarget, {
        sitekey: this.sitekeyValue,
        size: this.sizeValue,
        theme: this.themeValue,
        "refresh-expired": "auto",
        callback: (token) => this.solved(token),
        "error-callback": () => this.errored(),
        "expired-callback": () => this.expired(),
        "timeout-callback": () => this.timedOut(),
        "before-interactive-callback": () => this.interactive(),
        "unsupported-callback": () => this.unsupported()
      })
    } catch (error) {
      console.warn("Cloudflare Turnstile failed to render", error)
      this.failureMessage = STATUS.error
      this.hold("error")
    }
  }

  waitForTurnstile() {
    return new Promise((resolve) => {
      const timeoutAt = Date.now() + 15000

      const check = () => {
        if (this.cancelled) {
          resolve(null)
          return
        }

        // Do not call turnstile.ready() — it throws when api.js is loaded with
        // async/defer (see Cloudflare Turnstile docs / community reports).
        if (window.turnstile?.render) {
          resolve(window.turnstile)
          return
        }

        if (Date.now() > timeoutAt) {
          console.warn("Cloudflare Turnstile failed to load")
          resolve(null)
          return
        }

        requestAnimationFrame(check)
      }

      check()
    })
  }

  solved(token) {
    if (this.cancelled || !token) return

    this.attempts = 0
    this.release()
  }

  interactive() {
    if (this.cancelled || this.ready) return

    this.hold("challenge")
  }

  expired() {
    if (this.cancelled) return

    this.hold("pending")
  }

  timedOut() {
    if (this.cancelled) return

    this.failureMessage = STATUS.timeout
    this.hold("error")
  }

  unsupported() {
    if (this.cancelled) return

    this.failureMessage = STATUS.error
    this.hold("error")
  }

  errored() {
    if (this.cancelled) return false

    this.attempts += 1
    if (this.attempts < 3) {
      this.hold("pending")
      return true
    }

    this.failureMessage = STATUS.error
    this.hold("error")
    return false
  }

  hold(state) {
    this.ready = false
    if (state !== "error") this.failureMessage = null

    this.element.dataset.turnstileState = state
    this.submitControls().forEach((control) => this.disable(control, state))
    this.renderStatus(state)
  }

  release() {
    this.ready = true
    this.failureMessage = null
    this.element.dataset.turnstileState = "ready"
    this.submitControls().forEach((control) => this.restore(control))
    this.renderStatus("ready")
  }

  submitControls() {
    if (!this.form) return []

    return Array.from(this.form.querySelectorAll(SUBMIT_SELECTOR))
  }

  disable(control, state) {
    if (control.dataset.turnstileWasDisabled == null) {
      const alreadyGated = control.dataset.turnstileGate != null
      control.dataset.turnstileWasDisabled = !alreadyGated && control.disabled ? "true" : "false"
    }

    control.disabled = true
    control.dataset.turnstileGate = state

    if (state === "pending") {
      control.setAttribute("aria-busy", "true")
    } else {
      control.removeAttribute("aria-busy")
    }
  }

  restore(control) {
    control.disabled = control.dataset.turnstileWasDisabled === "true"
    delete control.dataset.turnstileGate
    control.removeAttribute("aria-busy")
  }

  renderStatus(state) {
    if (!this.hasStatusTarget || !this.hasStatusTextTarget) return

    const message = state === "error"
      ? (this.failureMessage || STATUS.error)
      : STATUS[state]

    this.statusTextTarget.textContent = message || ""
  }

  removeWidget() {
    if (this.widgetId == null || !window.turnstile?.remove) {
      this.widgetId = null
      return
    }

    try {
      window.turnstile.remove(this.widgetId)
    } catch {
      // Node may already be gone after a Turbo/portal move.
    }

    this.widgetId = null
  }
}
