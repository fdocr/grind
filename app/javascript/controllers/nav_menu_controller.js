import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu", "button" ]

  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
    this.boundKeydown = this.keydown.bind(this)
    // Always start closed. Turbo/Native restores can revive an open panel from a
    // snapshot or screenshot, which then blocks the page underneath.
    this.close()
  }

  disconnect() {
    this.removeListeners()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.syncAccessibility(false)
    this.removeListeners()
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.syncAccessibility(true)
    // Defer so the opening click does not immediately hit the document listener.
    window.setTimeout(() => {
      document.addEventListener("click", this.boundClickOutside)
      document.addEventListener("keydown", this.boundKeydown)
    }, 0)
  }

  isOpen() {
    return !this.menuTarget.classList.contains("hidden")
  }

  clickOutside(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  keydown(event) {
    if (event.key === "Escape") this.close()
  }

  syncAccessibility(open) {
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", open ? "true" : "false")
    }

    this.menuTarget.setAttribute("aria-hidden", open ? "false" : "true")
  }

  removeListeners() {
    document.removeEventListener("click", this.boundClickOutside)
    document.removeEventListener("keydown", this.boundKeydown)
  }
}
