import { Controller } from "@hotwired/stimulus"
import { GreenMap } from "lib/leaflet_green_map"

export default class extends Controller {
  static targets = [ "map", "holeButton", "progress", "calibration", "form" ]
  static values = {
    holes: Array,
    center: Array,
    tileUrl: String,
    tileAttribution: String,
    activeHole: Number
  }

  connect() {
    this.state = {}
    this.holesValue.forEach((hole) => {
      this.state[hole.number] = {
        polygon: hole.polygon || [],
        bbox: null,
        zoom: null,
        provider: "esri",
        clear: false
      }
    })

    this.activeHoleValue = this.holesValue[0]?.number || 1

    this.map = new GreenMap(this.mapTarget, {
      center: this.centerValue,
      zoom: 18,
      tileUrl: this.tileUrlValue,
      attribution: this.tileAttributionValue,
      onVertexAdd: (latlng) => this.addVertex(latlng),
      onMoveEnd: (viewport) => this.captureViewport(viewport)
    })

    this.loadHole(this.activeHoleValue)
    this.updateUI()
  }

  selectHole(event) {
    const number = Number(event.currentTarget.dataset.hole)
    if (!number || number === this.activeHoleValue) return

    this.saveCurrentHole()
    this.activeHoleValue = number
    this.loadHole(number)
    this.updateUI()
  }

  undo() {
    this.map.undo()
    this.markDirty()
    this.updateUI()
  }

  clearHole() {
    this.map.clear()
    this.state[this.activeHoleValue].clear = true
    this.state[this.activeHoleValue].polygon = []
    this.updateUI()
  }

  submit() {
    this.saveCurrentHole()
    const payload = {}

    Object.entries(this.state).forEach(([number, data]) => {
      if (data.clear) {
        payload[number] = { clear: true }
      } else if (data.polygon.length >= 3) {
        payload[number] = {
          polygon: data.polygon,
          bbox: data.bbox,
          zoom: data.zoom,
          provider: data.provider
        }
      }
    })

    this.calibrationTarget.value = JSON.stringify(payload)
  }

  addVertex(latlng) {
    this.state[this.activeHoleValue].clear = false
    this.map.addVertex(latlng)
    this.markDirty()
    this.updateUI()
  }

  saveCurrentHole() {
    const number = this.activeHoleValue
    const viewport = this.map.getViewport()
    const polygon = this.map.getPolygon()

    this.state[number].polygon = polygon
    this.state[number].bbox = viewport.bbox
    this.state[number].zoom = viewport.zoom
    if (polygon.length === 0) this.state[number].clear = true
  }

  loadHole(number) {
    const data = this.state[number]
    const hole = this.holesValue.find((entry) => entry.number === number)
    this.map.setVertices(data.polygon || [])

    if (hole?.centroid) {
      this.map.flyTo(hole.centroid, data.zoom || 18)
    } else if (this.centerValue) {
      this.map.flyTo(this.centerValue, 17)
    }
  }

  captureViewport(viewport) {
    const number = this.activeHoleValue
    this.state[number].bbox = viewport.bbox
    this.state[number].zoom = viewport.zoom
  }

  markDirty() {
    this.state[this.activeHoleValue].clear = false
    this.state[this.activeHoleValue].polygon = this.map.getPolygon()
  }

  updateUI() {
    const mappedCount = Object.values(this.state).filter((entry) => entry.polygon.length >= 3).length
    const total = this.holesValue.length

    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `${mappedCount} / ${total} greens mapped`
    }

    this.holeButtonTargets.forEach((button) => {
      const number = Number(button.dataset.hole)
      const mapped = (this.state[number]?.polygon || []).length >= 3
      const active = number === this.activeHoleValue
      button.dataset.state = active ? "active" : "inactive"
      button.setAttribute("aria-pressed", active ? "true" : "false")
      button.classList.toggle("ring-2", mapped)
      button.classList.toggle("ring-primary-500", mapped)
    })
  }
}
