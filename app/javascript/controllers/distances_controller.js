import { Controller } from "@hotwired/stimulus"
import { haversineMeters, nearestEdgeMeters, farthestVertexMeters, metersToYards } from "lib/geo"

const STORAGE_KEY = "grind:distanceUnit"

// Live GPS distances to the front, center and back of the current hole's green.
// Green geometry is passed in from the round controller (embedded in the page),
// so this works offline. The math lives in lib/geo.js to stay testable.
export default class extends Controller {
  static targets = ["title", "front", "center", "back", "accuracy", "status", "statusMessage", "empty", "content", "unitOption"]
  static values = { unit: String }

  connect() {
    this.unit = localStorage.getItem(STORAGE_KEY) || this.unitValue || "yds"
    this.green = null
    this.position = null
    this.accuracy = null
    this.watchId = null
    this.syncUnitButtons()
  }

  disconnect() {
    this.stop()
  }

  // Called by the round controller when the Distances panel opens.
  start(detail) {
    this.green = (detail && detail.green) || null
    const hole = detail && detail.hole
    if (this.hasTitleTarget) this.titleTarget.textContent = hole ? `Distances · Hole ${hole}` : "Distances"

    if (!this.green || !Array.isArray(this.green.polygon) || this.green.polygon.length < 3) {
      this.stop()
      this.showState("empty")
      return
    }

    if (this.position) this.render()
    this.beginWatch()
  }

  stop() {
    if (this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId)
      this.watchId = null
    }
  }

  retry() {
    if (this.green) this.beginWatch()
  }

  beginWatch() {
    if (!("geolocation" in navigator)) {
      this.showStatus("Location is not available on this device.")
      return
    }

    this.stop()
    if (!this.position) this.showStatus("Finding your location…")

    this.watchId = navigator.geolocation.watchPosition(
      (position) => this.onPosition(position),
      (error) => this.onError(error),
      { enableHighAccuracy: true, maximumAge: 2000, timeout: 27000 }
    )
  }

  onPosition(position) {
    this.position = [position.coords.latitude, position.coords.longitude]
    this.accuracy = position.coords.accuracy
    this.render()
  }

  onError(error) {
    if (error && error.code === 1) {
      this.showStatus("Enable location access to see distances.")
    } else {
      this.showStatus("We couldn't find your location. Try again.")
    }
  }

  setUnit(event) {
    const value = event.currentTarget.dataset.value
    if (!value || value === this.unit) return

    this.unit = value
    localStorage.setItem(STORAGE_KEY, value)
    this.syncUnitButtons()
    if (this.position && this.green) this.render()
  }

  render() {
    if (!this.green || !this.position) return

    this.showState("content")
    this.frontTarget.textContent = this.format(nearestEdgeMeters(this.position, this.green.polygon))
    this.centerTarget.textContent = this.format(haversineMeters(this.position, this.green.centroid))
    this.backTarget.textContent = this.format(farthestVertexMeters(this.position, this.green.polygon))

    if (this.hasAccuracyTarget) {
      this.accuracyTarget.textContent = this.accuracy
        ? `GPS accuracy ${this.convert(this.accuracy)} ${this.unitLabel}`
        : ""
    }
  }

  format(meters) {
    if (meters === null || Number.isNaN(meters)) return "—"
    return `${this.convert(meters)} ${this.unitLabel}`
  }

  convert(meters) {
    const value = this.unit === "m" ? meters : metersToYards(meters)
    return Math.round(value)
  }

  get unitLabel() {
    return this.unit === "m" ? "m" : "yds"
  }

  syncUnitButtons() {
    if (!this.hasUnitOptionTarget) return

    this.unitOptionTargets.forEach((button) => {
      const active = button.dataset.value === this.unit
      button.dataset.state = active ? "active" : "inactive"
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  showStatus(message) {
    if (this.hasStatusMessageTarget) this.statusMessageTarget.textContent = message
    this.showState("status")
  }

  showState(which) {
    if (this.hasContentTarget) this.toggle(this.contentTarget, which === "content")
    if (this.hasStatusTarget) this.toggle(this.statusTarget, which === "status")
    if (this.hasEmptyTarget) this.toggle(this.emptyTarget, which === "empty")
  }

  toggle(element, show) {
    element.classList.toggle("hidden", !show)
  }
}
