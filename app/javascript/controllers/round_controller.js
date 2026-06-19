import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "scoreToPar", "holeNumber", "insidePw9i", "oopTeeShots", "threePutts", "botchedUpDowns",
    "scorePanel", "holesPanel", "scorecardPanel", "overlay",
    "grossInput", "puttsInput", "finishButton", "finishForm", "startedAt",
    "scorecardBody", "holesList"
  ]

  static values = {
    course: Object
  }

  connect() {
    this.state = this.loadState()
    this.render()
    this.boundOnline = this.handleOnline.bind(this)
    window.addEventListener("online", this.boundOnline)
  }

  disconnect() {
    window.removeEventListener("online", this.boundOnline)
  }

  loadState() {
    const key = this.storageKey()
    const existing = localStorage.getItem(key)
    if (existing) return JSON.parse(existing)

    return {
      roundId: crypto.randomUUID(),
      startedAt: new Date().toISOString(),
      currentHole: 1,
      oopTeeShots: 0,
      threePutts: 0,
      botchedUpDowns: 0,
      insidePw9i: 0,
      holes: {},
      pendingFinish: false
    }
  }

  saveState() {
    localStorage.setItem(this.storageKey(), JSON.stringify(this.state))
  }

  storageKey() {
    return `grind:round:${this.courseValue.id}`
  }

  currentHoleData() {
    return this.courseValue.holes.find((hole) => hole.number === this.state.currentHole)
  }

  holeEntry(number) {
    return this.state.holes[number] || { gross: null, putts: null }
  }

  scoreToPar() {
    return this.courseValue.holes.reduce((total, hole) => {
      const entry = this.holeEntry(hole.number)
      if (entry.gross == null) return total
      return total + (entry.gross - hole.par)
    }, 0)
  }

  formatScoreToPar(value) {
    if (value === 0) return "Even"
    if (value > 0) return `+${value}`
    return `${value}`
  }

  formatInside(value) {
    if (value === 0) return "E"
    if (value > 0) return `+${value}`
    return `${value}`
  }

  allHolesComplete() {
    return this.courseValue.holes.every((hole) => {
      const entry = this.holeEntry(hole.number)
      return entry.gross != null && entry.gross !== ""
    })
  }

  render() {
    this.scoreToParTarget.textContent = this.formatScoreToPar(this.scoreToPar())
    this.holeNumberTarget.textContent = `Hole ${this.state.currentHole}`
    this.insidePw9iTarget.textContent = this.formatInside(this.state.insidePw9i)
    this.oopTeeShotsTarget.textContent = this.state.oopTeeShots
    this.threePuttsTarget.textContent = this.state.threePutts
    this.botchedUpDownsTarget.textContent = this.state.botchedUpDowns

    const entry = this.holeEntry(this.state.currentHole)
    this.grossInputTarget.value = entry.gross ?? ""
    this.puttsInputTarget.value = entry.putts ?? ""

    if (this.hasStartedAtTarget) {
      this.startedAtTarget.value = this.state.startedAt
    }

    if (this.hasFinishButtonTarget) {
      this.finishButtonTarget.disabled = !this.allHolesComplete()
    }

    this.renderScorecard()
    this.renderHolesList()
    this.saveState()
  }

  renderScorecard() {
    if (!this.hasScorecardBodyTarget) return

    const front = this.courseValue.holes.filter((hole) => hole.number <= 9)
    const back = this.courseValue.holes.filter((hole) => hole.number > 9)

    this.scorecardBodyTarget.innerHTML = ""
    this.scorecardBodyTarget.appendChild(this.buildNineTable("Front", front))
    this.scorecardBodyTarget.appendChild(this.buildNineTable("Back", back))
  }

  buildNineTable(label, holes) {
    const wrapper = document.createElement("div")
    wrapper.className = "mb-4"

    const title = document.createElement("h3")
    title.className = "text-sm font-semibold mb-2 text-muted-foreground"
    title.textContent = label
    wrapper.appendChild(title)

    const table = document.createElement("table")
    table.className = "ui-scorecard-table"

    const header = document.createElement("tr")
    ;["Hole", ...holes.map((hole) => hole.number), "Total"].forEach((cell) => {
      const th = document.createElement("th")
      th.textContent = cell
      header.appendChild(th)
    })
    table.appendChild(header)

    const hcpRow = document.createElement("tr")
    ;["Hcp", ...holes.map((hole) => hole.handicap), ""].forEach((cell) => {
      const td = document.createElement("td")
      td.textContent = cell
      hcpRow.appendChild(td)
    })
    table.appendChild(hcpRow)

    const scoreRow = document.createElement("tr")
    const scores = holes.map((hole) => {
      const entry = this.holeEntry(hole.number)
      return entry.gross == null ? "·" : entry.gross
    })
    const total = holes.reduce((sum, hole) => {
      const entry = this.holeEntry(hole.number)
      return entry.gross == null ? sum : sum + Number(entry.gross)
    }, 0)

    ;["Score", ...scores, total || "·"].forEach((cell) => {
      const td = document.createElement("td")
      td.textContent = cell
      scoreRow.appendChild(td)
    })
    table.appendChild(scoreRow)

    wrapper.appendChild(table)
    return wrapper
  }

  renderHolesList() {
    if (!this.hasHolesListTarget) return

    this.holesListTarget.innerHTML = ""
    this.courseValue.holes.forEach((hole) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "ui-btn-secondary ui-btn-sm w-full justify-between"
      const entry = this.holeEntry(hole.number)
      const scoreLabel = entry.gross == null ? "Open" : `Score ${entry.gross}`
      button.textContent = `Hole ${hole.number} · Par ${hole.par} · ${scoreLabel}`
      button.addEventListener("click", () => {
        this.state.currentHole = hole.number
        this.closePanels()
        this.render()
      })
      this.holesListTarget.appendChild(button)
    })
  }

  increment(event) {
    const stat = event.currentTarget.dataset.stat
    if (stat === "insidePw9i") {
      this.state.insidePw9i += 1
    } else {
      this.state[stat] += 1
    }
    this.render()
  }

  decrement(event) {
    const stat = event.currentTarget.dataset.stat
    if (stat === "insidePw9i") {
      this.state.insidePw9i -= 1
    } else if (this.state[stat] > 0) {
      this.state[stat] -= 1
    }
    this.render()
  }

  openScorePanel() {
    this.showPanel(this.scorePanelTarget)
  }

  openHolesPanel() {
    this.showPanel(this.holesPanelTarget)
  }

  openScorecardPanel() {
    this.renderScorecard()
    this.showPanel(this.scorecardPanelTarget)
  }

  showPanel(panel) {
    this.overlayTarget.classList.remove("hidden")
    ;[this.scorePanelTarget, this.holesPanelTarget, this.scorecardPanelTarget].forEach((element) => {
      element.classList.add("hidden")
    })
    panel.classList.remove("hidden")
  }

  closePanels() {
    this.overlayTarget.classList.add("hidden")
    ;[this.scorePanelTarget, this.holesPanelTarget, this.scorecardPanelTarget].forEach((element) => {
      element.classList.add("hidden")
    })
  }

  saveHoleScore() {
    const gross = this.grossInputTarget.value === "" ? null : Number(this.grossInputTarget.value)
    const putts = this.puttsInputTarget.value === "" ? null : Number(this.puttsInputTarget.value)

    this.state.holes[this.state.currentHole] = { gross, putts }
    this.closePanels()
    this.render()
  }

  previousHole() {
    if (this.state.currentHole > 1) {
      this.state.currentHole -= 1
      this.render()
    }
  }

  nextHole() {
    if (this.state.currentHole < 18) {
      this.state.currentHole += 1
      this.render()
    }
  }

  finishRound() {
    if (!this.allHolesComplete()) return

    if (!navigator.onLine) {
      this.state.pendingFinish = true
      this.saveState()
      alert("You are offline. Your round will post automatically when you reconnect.")
      return
    }

    this.submitFinish()
  }

  handleOnline() {
    if (this.state.pendingFinish && this.allHolesComplete()) {
      this.submitFinish()
    }
  }

  submitFinish() {
    if (!this.hasFinishFormTarget) return

    const holeScores = {}
    this.courseValue.holes.forEach((hole) => {
      const entry = this.holeEntry(hole.number)
      holeScores[hole.number] = { gross: entry.gross, putts: entry.putts }
    })

    const form = this.finishFormTarget
    form.querySelector('[name="round[oop_tee_shots]"]').value = this.state.oopTeeShots
    form.querySelector('[name="round[three_putts]"]').value = this.state.threePutts
    form.querySelector('[name="round[botched_up_downs]"]').value = this.state.botchedUpDowns
    form.querySelector('[name="round[inside_pw_9i]"]').value = this.state.insidePw9i
    form.querySelector('[name="round[started_at]"]').value = this.state.startedAt

    const container = form.querySelector("[data-round-hole-scores]")
    container.innerHTML = ""
    Object.entries(holeScores).forEach(([number, entry]) => {
      const gross = document.createElement("input")
      gross.type = "hidden"
      gross.name = `round[hole_scores][${number}][gross]`
      gross.value = entry.gross
      container.appendChild(gross)

      const putts = document.createElement("input")
      putts.type = "hidden"
      putts.name = `round[hole_scores][${number}][putts]`
      putts.value = entry.putts ?? ""
      container.appendChild(putts)
    })

    localStorage.removeItem(this.storageKey())
    this.state.pendingFinish = false
    form.requestSubmit()
  }
}
