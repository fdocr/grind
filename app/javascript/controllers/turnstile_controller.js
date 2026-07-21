import { Controller } from "@hotwired/stimulus"

// Explicit Turnstile rendering for Turbo Frame / modal portals.
// Implicit api.js scanning only runs on first page load, so widgets injected
// later (course sheet, Turbo visits) need turnstile.render() on connect.
export default class extends Controller {
  static targets = ["widget"]
  static values = {
    sitekey: String,
    size: { type: String, default: "flexible" },
    theme: { type: String, default: "auto" }
  }

  connect() {
    this.widgetId = null
    this.cancelled = false
    this.renderWhenReady()
  }

  disconnect() {
    this.cancelled = true
    this.removeWidget()
  }

  async renderWhenReady() {
    const turnstile = await this.waitForTurnstile()
    if (this.cancelled || !turnstile || !this.hasWidgetTarget) return

    // Parent modal portals synchronously in its connect (before children).
    // Defer one frame so a mid-move reconnect settles on document.body first.
    await new Promise((resolve) => requestAnimationFrame(resolve))
    if (this.cancelled || !this.hasWidgetTarget) return

    this.removeWidget()
    this.widgetId = turnstile.render(this.widgetTarget, {
      sitekey: this.sitekeyValue,
      size: this.sizeValue,
      theme: this.themeValue
    })
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
