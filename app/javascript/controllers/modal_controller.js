import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  close() {
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.innerHTML = ""
    } else {
      this.element.remove()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
