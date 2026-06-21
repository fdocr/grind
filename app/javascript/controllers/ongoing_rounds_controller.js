import { Controller } from "@hotwired/stimulus"

const KEY_PREFIX = "grind:round:"

export default class extends Controller {
  static targets = ["list"]

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
    meta.textContent = `${round.holesScored} ${round.holesScored === 1 ? "hole" : "holes"} scored`

    info.appendChild(name)
    info.appendChild(meta)

    const link = document.createElement("a")
    link.href = `/courses/${round.courseId}/round`
    link.className = "ui-btn-primary ui-btn-sm shrink-0"
    link.textContent = "Continue"

    card.appendChild(info)
    card.appendChild(link)
    return card
  }
}
