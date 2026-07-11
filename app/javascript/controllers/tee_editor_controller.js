// Dynamic add/remove for course tee cards on the admin course form.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template", "tee", "removeButton", "nameInput"]

  connect() {
    this.nextIndex = this.teeTargets.length
    this.syncRemoveButtons()
  }

  add() {
    const html = this.templateTarget.innerHTML.replaceAll("NEW_INDEX", String(this.nextIndex))
    this.nextIndex += 1
    this.listTarget.insertAdjacentHTML("beforeend", html)

    const tee = this.teeTargets[this.teeTargets.length - 1]
    const nameInput = tee.querySelector("[data-tee-editor-target='nameInput']")
    if (nameInput) {
      nameInput.value = ""
      nameInput.focus()
    }

    this.syncRemoveButtons()
  }

  remove(event) {
    if (this.teeTargets.length <= 1) return

    const tee = event.currentTarget.closest("[data-tee-editor-target='tee']")
    if (tee) tee.remove()
    this.syncRemoveButtons()
  }

  syncRemoveButtons() {
    const onlyOne = this.teeTargets.length <= 1
    this.removeButtonTargets.forEach((button) => {
      button.disabled = onlyOne
      button.classList.toggle("opacity-40", onlyOne)
      button.classList.toggle("cursor-not-allowed", onlyOne)
    })
  }
}
