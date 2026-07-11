import { Controller } from "@hotwired/stimulus"

// Course preview overlay. Portals to document.body so position:fixed covers the
// real viewport (fixed inside turbo-frame is unreliable in WKWebView / Native).
export default class extends Controller {
  connect() {
    this.portalToBody()

    // Moving the node triggers a Stimulus disconnect/connect cycle. Init once.
    if (this.element.dataset.modalActive === "true") return
    this.element.dataset.modalActive = "true"

    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
    document.documentElement.classList.add("overflow-hidden")
  }

  disconnect() {
    // Portal move: left the frame but already on body — keep the overlay alive.
    if (this.element.dataset.modalPortal === "true" && document.body.contains(this.element)) {
      return
    }
    this.teardown()
  }

  close() {
    this.teardown()
    document.getElementById("course_modal")?.replaceChildren()
  }

  portalToBody() {
    if (this.element.dataset.modalPortal === "true") return

    this.placeholder = document.createComment("modal-portal")
    this.element.parentNode?.insertBefore(this.placeholder, this.element)
    this.element.dataset.modalPortal = "true"
    document.body.appendChild(this.element)
  }

  teardown() {
    document.documentElement.classList.remove("overflow-hidden")

    const handler = this.boundKeydown
    if (handler) {
      document.removeEventListener("keydown", handler)
      this.boundKeydown = null
    }

    if (this.element) {
      delete this.element.dataset.modalActive
      delete this.element.dataset.modalPortal
      if (this.element.isConnected) this.element.remove()
    }

    this.placeholder?.remove()
    this.placeholder = null
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
