import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["offline"]

  connect() {
    this.element.classList.remove("hidden")
    this.update()
    this.boundUpdate = this.update.bind(this)
    window.addEventListener("online", this.boundUpdate)
    window.addEventListener("offline", this.boundUpdate)
  }

  disconnect() {
    window.removeEventListener("online", this.boundUpdate)
    window.removeEventListener("offline", this.boundUpdate)
  }

  update() {
    const offline = !navigator.onLine
    if (this.hasOfflineTarget) {
      this.offlineTarget.classList.toggle("hidden", !offline)
    }
    document.documentElement.dataset.offline = offline ? "true" : "false"
  }
}
