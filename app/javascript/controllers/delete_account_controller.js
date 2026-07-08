import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["confirm", "form"]

  openConfirm() {
    this.confirmTarget.classList.remove("hidden")
  }

  cancel() {
    this.confirmTarget.classList.add("hidden")
  }

  confirmDelete() {
    this.confirmTarget.classList.add("hidden")
    this.formTarget.querySelector("form")?.requestSubmit()
  }
}
