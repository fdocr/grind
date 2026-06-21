import { Controller } from "@hotwired/stimulus"

const KEY_PREFIX = "grind:round:"

export default class extends Controller {
  static targets = ["list", "confirm", "confirmName", "continueIcon", "clearIcon"]

  connect() {
    this.render()
  }

  render() {
    const rounds = this.ongoingRounds()

    if (rounds.length === 0) {
      this.element.classList.add("hidden")
      return
    }

    this.element.classList.remove("hidden")
    this.listTarget.innerHTML = ""
    rounds.forEach((round) => this.listTarget.appendChild(this.buildCard(round)))
  }

  ongoingRounds() {
    const rounds = []

    for (let index = 0; index < localStorage.length; index++) {
      const key = localStorage.key(index)
      if (!key || !key.startsWith(KEY_PREFIX)) continue

      let state
      try {
        state = JSON.parse(localStorage.getItem(key))
      } catch (error) {
        continue
      }

      const holesScored = state && state.holes ? Object.keys(state.holes).length : 0
      if (holesScored === 0) continue

      rounds.push({
        courseId: state.courseId ?? key.slice(KEY_PREFIX.length),
        courseName: state.courseName,
        tee: state.tee,
        holesScored,
        startedAt: state.startedAt
      })
    }

    return rounds.sort((a, b) => new Date(b.startedAt || 0) - new Date(a.startedAt || 0))
  }

  buildCard(round) {
    const card = document.createElement("div")
    card.className = "rounded-lg border border-border bg-card text-card-foreground shadow-card p-4 flex items-center justify-between gap-3"

    const info = document.createElement("div")
    info.className = "min-w-0"

    const name = document.createElement("p")
    name.className = "font-semibold truncate"
    name.textContent = round.courseName || "Round in progress"

    const meta = document.createElement("p")
    meta.className = "text-sm text-muted-foreground"
    const teeLabel = round.tee ? `${this.titleize(round.tee)} tee · ` : ""
    meta.textContent = `${teeLabel}${round.holesScored} ${round.holesScored === 1 ? "hole" : "holes"} scored`

    info.appendChild(name)
    info.appendChild(meta)

    const actions = document.createElement("div")
    actions.className = "flex items-center gap-2 shrink-0"

    const teeParam = round.tee ? `?tee=${encodeURIComponent(round.tee)}` : ""
    const continueLink = document.createElement("a")
    continueLink.href = `/courses/${round.courseId}/round${teeParam}`
    continueLink.className = "ui-icon-btn !text-primary-600 hover:!text-primary-700"
    continueLink.setAttribute("aria-label", `Continue round at ${round.courseName || "course"}`)
    continueLink.appendChild(this.iconNode(this.continueIconTarget))

    const clearButton = document.createElement("button")
    clearButton.type = "button"
    clearButton.className = "ui-icon-btn hover:!text-danger-700"
    clearButton.setAttribute("aria-label", `Clear round at ${round.courseName || "course"}`)
    clearButton.appendChild(this.iconNode(this.clearIconTarget))
    clearButton.addEventListener("click", () => this.requestClear(round))

    actions.appendChild(continueLink)
    actions.appendChild(clearButton)

    card.appendChild(info)
    card.appendChild(actions)
    return card
  }

  iconNode(template) {
    return template.content.firstElementChild.cloneNode(true)
  }

  requestClear(round) {
    this.pendingKey = `${KEY_PREFIX}${round.courseId}`
    if (this.hasConfirmNameTarget) {
      this.confirmNameTarget.textContent = round.courseName || "this course"
    }
    this.confirmTarget.classList.remove("hidden")
  }

  cancelClear() {
    this.pendingKey = null
    this.confirmTarget.classList.add("hidden")
  }

  confirmClear() {
    if (this.pendingKey) localStorage.removeItem(this.pendingKey)
    this.pendingKey = null
    this.confirmTarget.classList.add("hidden")
    this.render()
  }

  titleize(value) {
    return value.replace(/\b\w/g, (char) => char.toUpperCase())
  }
}
