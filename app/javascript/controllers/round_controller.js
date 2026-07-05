import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "scoreToPar", "holeNumber", "insidePw9i", "oopTeeShots", "threePutts", "botchedUpDowns",
    "scorePanel", "holesPanel", "scorecardPanel", "resetPanel", "distancesPanel", "overlay",
    "grossInput", "puttsInput", "grossPicker", "puttsPicker",
    "scorePanelHole", "scorePanelPar", "scorePanelHcp", "scorePanelYards", "holeMeta",
    "finishButton", "finishForm", "startedAt",
    "scorecardBody", "holesList", "statsLastHole", "statsLastHoleLabel", "holeScoredIcon"
  ]

  static values = {
    course: Object,
    tee: String
  }

  connect() {
    this.state = this.loadState()
    this.state.courseId = this.courseValue.id
    this.state.courseName = this.courseValue.name
    this.state.tee = this.teeValue
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

    return this.defaultState()
  }

  unit() {
    return this.courseValue.unit || "yds"
  }

  defaultState() {
    return {
      roundId: crypto.randomUUID(),
      courseId: this.courseValue.id,
      courseName: this.courseValue.name,
      tee: this.teeValue,
      startedAt: new Date().toISOString(),
      currentHole: 1,
      oopTeeShots: 0,
      botchedUpDowns: 0,
      insidePw9i: 0,
      statsLastHole: null,
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

  lastHoleNumber() {
    if (!this.courseValue.holes.length) return 1
    return Math.max(...this.courseValue.holes.map((hole) => hole.number))
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

  threePuttCount() {
    return Object.values(this.state.holes)
      .filter((entry) => Number(entry.putts) >= 3).length
  }

  render() {
    this.scoreToParTarget.textContent = this.formatScoreToPar(this.scoreToPar())
    this.holeNumberTarget.textContent = `Hole ${this.state.currentHole}`

    const hole = this.currentHoleData()
    if (hole && this.hasHoleMetaTarget) {
      const yards = hole.yardage ? ` · ${hole.yardage} ${this.unit()}` : ""
      this.holeMetaTarget.textContent = `Par ${hole.par} · Hcp ${hole.handicap}${yards}`
    }

    this.insidePw9iTarget.textContent = this.formatInside(this.state.insidePw9i)
    this.oopTeeShotsTarget.textContent = this.state.oopTeeShots
    this.threePuttsTarget.textContent = this.threePuttCount()
    this.botchedUpDownsTarget.textContent = this.state.botchedUpDowns

    if (this.hasStartedAtTarget) {
      this.startedAtTarget.value = this.state.startedAt
    }

    if (this.hasFinishButtonTarget) {
      this.finishButtonTarget.disabled = !this.allHolesComplete()
    }

    this.renderScorecard()
    this.renderHolesList()
    this.renderStatsLastHole()
    this.saveState()
  }

  renderStatsLastHole() {
    if (!this.hasStatsLastHoleTarget) return

    const hole = this.state.statsLastHole
    if (hole == null) {
      this.statsLastHoleTarget.classList.add("hidden")
      return
    }

    this.statsLastHoleTarget.classList.remove("hidden")
    if (this.hasStatsLastHoleLabelTarget) {
      this.statsLastHoleLabelTarget.textContent = `Hole ${hole}`
    }
  }

  renderScorecard() {
    if (!this.hasScorecardBodyTarget) return

    const front = this.courseValue.holes.filter((hole) => hole.number <= 9)
    const back = this.courseValue.holes.filter((hole) => hole.number > 9)

    this.scorecardBodyTarget.innerHTML = ""
    this.scorecardBodyTarget.appendChild(this.buildNineTable("Front", front))
    if (back.length > 0) {
      this.scorecardBodyTarget.appendChild(this.buildNineTable("Back", back))
    }
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

    const scroll = document.createElement("div")
    scroll.className = "ui-scorecard-scroll"

    const header = document.createElement("tr")
    ;["Hole", ...holes.map((hole) => hole.number), "Total"].forEach((cell) => {
      const th = document.createElement("th")
      th.textContent = cell
      header.appendChild(th)
    })
    table.appendChild(header)

    const parRow = document.createElement("tr")
    const parTotal = holes.reduce((sum, hole) => sum + hole.par, 0)
    ;["Par", ...holes.map((hole) => hole.par), parTotal].forEach((cell) => {
      const td = document.createElement("td")
      td.textContent = cell
      parRow.appendChild(td)
    })
    table.appendChild(parRow)

    const hcpRow = document.createElement("tr")
    ;["Hcp", ...holes.map((hole) => hole.handicap), ""].forEach((cell) => {
      const td = document.createElement("td")
      td.textContent = cell
      hcpRow.appendChild(td)
    })
    table.appendChild(hcpRow)

    if (holes.some((hole) => hole.yardage)) {
      const yardsRow = document.createElement("tr")
      const yardsTotal = holes.reduce((sum, hole) => sum + (hole.yardage || 0), 0)
      ;[this.unit().charAt(0).toUpperCase() + this.unit().slice(1), ...holes.map((hole) => hole.yardage || "·"), yardsTotal || "·"].forEach((cell) => {
        const td = document.createElement("td")
        td.textContent = cell
        yardsRow.appendChild(td)
      })
      table.appendChild(yardsRow)
    }

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

    scroll.appendChild(table)
    wrapper.appendChild(scroll)
    return wrapper
  }

  renderHolesList() {
    if (!this.hasHolesListTarget) return

    this.holesListTarget.innerHTML = ""

    const frontHoles = this.courseValue.holes.filter((hole) => hole.number <= 9)
    const backHoles = this.courseValue.holes.filter((hole) => hole.number > 9)

    const grid = document.createElement("div")
    grid.className = backHoles.length > 0 ? "grid grid-cols-2 gap-2" : "grid grid-cols-1 gap-2"

    const frontColumn = document.createElement("div")
    frontColumn.className = "space-y-1.5"

    frontHoles.forEach((hole) => {
      frontColumn.appendChild(this.buildHoleButton(hole))
    })

    grid.appendChild(frontColumn)

    if (backHoles.length > 0) {
      const backColumn = document.createElement("div")
      backColumn.className = "space-y-1.5"
      backHoles.forEach((hole) => {
        backColumn.appendChild(this.buildHoleButton(hole))
      })
      grid.appendChild(backColumn)
    }

    this.holesListTarget.appendChild(grid)
  }

  buildHoleButton(hole) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "ui-btn-secondary ui-btn-sm w-full text-left !justify-between flex-row items-center gap-2 h-auto py-1.5 px-2.5"
    button.dataset.holeNumber = hole.number
    button.setAttribute("aria-label", `Hole ${hole.number}`)

    const entry = this.holeEntry(hole.number)
    const scored = entry.gross != null && entry.gross !== ""

    const label = document.createElement("span")
    label.className = "flex items-center gap-1.5 min-w-0"

    const number = document.createElement("span")
    number.className = "font-semibold text-sm tabular-nums"
    number.textContent = hole.number

    const par = document.createElement("span")
    par.className = "text-xs text-muted-foreground"
    par.textContent = `Par ${hole.par}`

    label.appendChild(number)
    label.appendChild(par)
    button.appendChild(label)

    if (scored && this.hasHoleScoredIconTarget) {
      button.appendChild(this.holeScoredIconTarget.content.cloneNode(true))
    }

    button.addEventListener("click", () => {
      this.state.currentHole = hole.number
      this.closePanels()
      this.render()
    })
    return button
  }

  touchStatCounter() {
    this.state.statsLastHole = this.state.currentHole
  }

  increment(event) {
    const stat = event.currentTarget.dataset.stat
    if (stat === "insidePw9i") {
      this.state.insidePw9i += 1
    } else {
      this.state[stat] += 1
    }
    this.touchStatCounter()
    this.render()
  }

  decrement(event) {
    const stat = event.currentTarget.dataset.stat
    if (stat === "insidePw9i") {
      this.state.insidePw9i -= 1
    } else if (this.state[stat] > 0) {
      this.state[stat] -= 1
    }
    this.touchStatCounter()
    this.render()
  }

  openScorePanel() {
    this.populatePostScorePanel()
    this.showPanel(this.scorePanelTarget)
  }

  populatePostScorePanel() {
    const hole = this.currentHoleData()
    if (!hole) return

    const entry = this.holeEntry(this.state.currentHole)
    const gross = entry.gross ?? hole.par
    const putts = entry.putts ?? 2

    if (this.hasScorePanelHoleTarget) this.scorePanelHoleTarget.textContent = `Hole ${hole.number}`
    if (this.hasScorePanelParTarget) this.scorePanelParTarget.textContent = `Par ${hole.par}`
    if (this.hasScorePanelHcpTarget) this.scorePanelHcpTarget.textContent = `Hcp ${hole.handicap}`
    if (this.hasScorePanelYardsTarget) {
      this.scorePanelYardsTarget.textContent = hole.yardage ? `${hole.yardage} ${this.unit()}` : "—"
      this.scorePanelYardsTarget.classList.toggle("hidden", !hole.yardage)
    }

    const grossValues = Array.from({ length: 12 }, (_, index) => index + 1)

    this.buildPicker(this.grossPickerTarget, grossValues, gross)
    this.buildPicker(this.puttsPickerTarget, Array.from({ length: 7 }, (_, index) => index), putts)

    this.grossInputTarget.value = gross
    this.puttsInputTarget.value = putts
  }

  buildPicker(container, values, selected) {
    container.innerHTML = ""
    values.forEach((value) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "ui-picker-option"
      button.dataset.value = value
      button.dataset.state = Number(value) === Number(selected) ? "active" : "inactive"
      button.textContent = value
      button.setAttribute("aria-pressed", button.dataset.state === "active" ? "true" : "false")
      container.appendChild(button)
    })

    this.scrollPickerToSelected(container)
  }

  scrollPickerToSelected(container) {
    const active = container.querySelector('[data-state="active"]')
    if (active) {
      active.scrollIntoView({ behavior: "instant", inline: "center", block: "nearest" })
    }
  }

  pickGross(event) {
    const button = event.target.closest("[data-value]")
    if (!button || !this.hasGrossPickerTarget) return

    this.selectPickerOption(this.grossPickerTarget, button)
    this.grossInputTarget.value = button.dataset.value
  }

  pickPutts(event) {
    const button = event.target.closest("[data-value]")
    if (!button || !this.hasPuttsPickerTarget) return

    this.selectPickerOption(this.puttsPickerTarget, button)
    this.puttsInputTarget.value = button.dataset.value
  }

  selectPickerOption(container, selectedButton) {
    container.querySelectorAll(".ui-picker-option").forEach((button) => {
      const active = button === selectedButton
      button.dataset.state = active ? "active" : "inactive"
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  openDistancesPanel() {
    const controller = this.distancesController()
    if (controller) {
      const hole = this.currentHoleData()
      controller.start({ green: hole && hole.green, hole: this.state.currentHole })
    }
    this.showPanel(this.distancesPanelTarget)
  }

  distancesController() {
    if (!this.hasDistancesPanelTarget) return null
    return this.application.getControllerForElementAndIdentifier(this.distancesPanelTarget, "distances")
  }

  openHolesPanel() {
    this.showPanel(this.holesPanelTarget)
  }

  openScorecardPanel() {
    this.renderScorecard()
    this.showPanel(this.scorecardPanelTarget)
  }

  openResetPanel() {
    this.showPanel(this.resetPanelTarget)
  }

  confirmReset() {
    localStorage.removeItem(this.storageKey())
    this.state = this.defaultState()
    this.closePanels()
    this.render()
  }

  panelTargets() {
    return [
      this.scorePanelTarget,
      this.holesPanelTarget,
      this.scorecardPanelTarget,
      this.resetPanelTarget,
      this.distancesPanelTarget
    ]
  }

  showPanel(panel) {
    this.overlayTarget.classList.remove("hidden")
    this.panelTargets().forEach((element) => element.classList.add("hidden"))
    panel.classList.remove("hidden")
  }

  closePanels() {
    this.overlayTarget.classList.add("hidden")
    this.panelTargets().forEach((element) => element.classList.add("hidden"))

    const distances = this.distancesController()
    if (distances) distances.stop()
  }

  saveHoleScore() {
    const gross = Number(this.grossInputTarget.value)
    const putts = Number(this.puttsInputTarget.value)

    this.state.holes[this.state.currentHole] = { gross, putts }
    this.advanceAfterScore()

    this.closePanels()
    this.render()
  }

  // After posting, advance to the next hole. On the last hole, wrap to hole 1
  // when it still has no score (shotgun starts that finish 18 before playing 1).
  advanceAfterScore() {
    const last = this.lastHoleNumber()

    if (this.state.currentHole < last) {
      this.state.currentHole += 1
      return
    }

    if (this.state.currentHole === last) {
      const first = this.holeEntry(1)
      if (first.gross == null || first.gross === "") {
        this.state.currentHole = 1
      }
    }
  }

  previousHole() {
    if (this.state.currentHole > 1) {
      this.state.currentHole -= 1
      this.render()
    }
  }

  nextHole() {
    if (this.state.currentHole < this.lastHoleNumber()) {
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

    form.requestSubmit()
  }

  submitEnd(event) {
    if (!event.detail.success) return

    localStorage.removeItem(this.storageKey())
    this.state.pendingFinish = false
  }
}
