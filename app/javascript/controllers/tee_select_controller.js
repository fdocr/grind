import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "yardage", "rating", "slope", "totalOut", "totalIn", "startLink", "teeInput"]
  static values = { tees: Object, active: String }

  connect() {
    this.apply()
  }

  select(event) {
    const value = event.currentTarget.dataset.value
    if (!value) return

    this.activeValue = value
    this.apply()
  }

  apply() {
    const tee = this.teesValue[this.activeValue] || {}
    const yardages = (tee.yardages || []).map((value) => Number(value) || 0)

    this.yardageTargets.forEach((cell) => {
      const hole = Number(cell.dataset.hole)
      cell.textContent = this.format(yardages[hole - 1])
    })

    const sum = (start, end) => yardages.slice(start, end).reduce((total, value) => total + (value > 0 ? value : 0), 0)
    if (this.hasTotalOutTarget) this.totalOutTarget.textContent = this.format(sum(0, 9))
    if (this.hasTotalInTarget) this.totalInTarget.textContent = this.format(sum(9, 18))

    if (this.hasRatingTarget) this.ratingTarget.textContent = tee.rating ? tee.rating : "—"
    if (this.hasSlopeTarget) this.slopeTarget.textContent = tee.slope ? tee.slope : "—"

    this.optionTargets.forEach((button) => {
      const active = button.dataset.value === this.activeValue
      button.dataset.state = active ? "active" : "inactive"
    })

    if (this.hasStartLinkTarget) {
      const url = new URL(this.startLinkTarget.href, window.location.origin)
      url.searchParams.set("tee", this.activeValue)
      this.startLinkTarget.href = url.pathname + url.search
    }

    if (this.hasTeeInputTarget) this.teeInputTarget.value = this.activeValue
  }

  format(value) {
    return value && value > 0 ? value : "—"
  }
}
