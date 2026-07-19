import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { haversineMeters, nearestEdgeMeters, farthestVertexMeters, metersToYards } from "lib/geo"
import { DistanceMap } from "lib/leaflet_distance_map"

const STORAGE_KEY = "grind:distanceUnit"
const PAYLOAD_KEY = "grind:distancesPayload"
const TOO_FAR_METERS = 800

// First-paint GPS warm-up: avoid flashing a coarse fix before GPS settles.
const GOOD_ACCURACY_M = 30
const MIN_WARMUP_SAMPLES = 3
const MIN_WARMUP_MS = 2000
const MAX_WARMUP_MS = 4500
// After lock: ignore jitter unless we moved or accuracy improved meaningfully.
const MOVE_UPDATE_M = 2.5
const ACCURACY_IMPROVE_M = 5

// Live GPS distances to the front, center and back of the current hole's green.
// Green geometry is passed in from the round controller (embedded in the page),
// so this works offline. The math lives in lib/geo.js to stay testable.
//
// Map view (Numbers | Map) uses Leaflet satellite tiles with a red yardage line
// and an optional pivot that splits the shot into two segments.
//
// This is a Hotwire Native BridgeComponent named "geolocation". When running
// inside the native apps it always uses the bridge (CoreLocation /
// FusedLocationProvider) — never navigator.geolocation — so WKWebView does not
// also prompt for location. send("start") queues until the bridge adapter is
// ready. Browsers / PWA fall back to watchPosition as before.
export default class extends BridgeComponent {
  static component = "geolocation"
  static targets = [
    "front", "center", "back", "accuracy", "status", "statusLoading", "statusLoadingMessage",
    "statusError", "statusErrorTitle", "statusErrorMessage", "empty", "tooFar", "content",
    "unitOption", "numbers", "map", "mapContainer", "clearPivot", "viewOption", "viewToggle", "holeLabel"
  ]
  static values = {
    unit: String,
    tileUrl: String,
    tileAttribution: String,
    green: Object,
    autostart: Boolean
  }

  // BridgeComponent gates loading on native support by default; force it to
  // always load so the browser fallback keeps working.
  static get shouldLoad() {
    return true
  }

  // True inside Hotwire Native even before the bridge adapter attaches
  // (when this.enabled is still false). Prefer UA / dataset over this.enabled.
  get nativeApp() {
    const { bridgePlatform, bridgeComponents } = document.documentElement.dataset
    if (bridgePlatform || (bridgeComponents && bridgeComponents.includes("geolocation"))) return true

    const ua = navigator.userAgent || ""
    return /\bHotwire Native\b/i.test(ua) || /bridge-components:\s*\[[^\]]*geolocation/.test(ua)
  }

  connect() {
    super.connect()
    this.unit = localStorage.getItem(STORAGE_KEY) || this.unitValue || "yds"
    this.green = null
    this.watchId = null
    this.view = "numbers"
    this.pivot = null
    this.distanceMap = null
    this.didFitMap = false
    this.resetGpsFix()
    this.syncUnitButtons()
    this.syncViewButtons()

    // Native modal shell: green/hole come from the round page via localStorage
    // so opening Distances does not need a course-specific network fetch.
    // localStorage is required because the modal session is a separate WKWebView.
    // Do not remove the payload on read — Turbo/Native may reconnect the
    // controller when reopening the sheet, and the round page overwrites it
    // on each Distances tap.
    if (this.autostartValue) {
      this.autostartFromPayload()
      this.boundPageshow = () => this.autostartFromPayload()
      window.addEventListener("pageshow", this.boundPageshow)
    }
  }

  autostartFromPayload() {
    const payload = this.payloadFromStorage()
    if (payload) {
      this.applyHoleLabel(payload)
      // Reuse a live session when the green hasn't changed (pageshow / reconnect).
      if (!this.sameGreen(payload.green)) this.start({ green: payload.green })
      else if (this.position) this.render()
      return
    }

    // Only fall back to the Stimulus value on the first attempt; later
    // pageshow/reconnects without a payload should not wipe a live session.
    if (!this.green) {
      this.start({ green: this.hasGreenValue ? this.greenValue : null })
    }
  }

  sameGreen(green) {
    if (!this.green || !green) return false
    try {
      return JSON.stringify(this.green) === JSON.stringify(green)
    } catch {
      return false
    }
  }

  payloadFromStorage() {
    try {
      const raw = localStorage.getItem(PAYLOAD_KEY)
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  }

  applyHoleLabel(payload) {
    if (!this.hasHoleLabelTarget) return

    if (payload.holeNumber != null && payload.holePar != null) {
      this.holeLabelTarget.textContent = `Hole ${payload.holeNumber} · Par ${payload.holePar}`
      this.holeLabelTarget.classList.remove("hidden")
    } else {
      this.holeLabelTarget.textContent = ""
      this.holeLabelTarget.classList.add("hidden")
    }
  }

  disconnect() {
    if (this.boundPageshow) {
      window.removeEventListener("pageshow", this.boundPageshow)
      this.boundPageshow = null
    }
    this.stop()
    super.disconnect()
  }

  // Called by the round controller when the Distances panel opens.
  start(detail) {
    this.green = (detail && detail.green) || null
    this.pivot = null
    this.view = "numbers"
    this.didFitMap = false
    this.resetGpsFix()
    this.destroyMap()
    this.syncViewButtons()
    this.syncViewVisibility()
    this.syncClearButton()

    if (!this.green || !Array.isArray(this.green.polygon) || this.green.polygon.length < 3) {
      this.stop()
      this.showState("empty")
      return
    }

    this.beginWatch()
  }

  stop() {
    this.stopWatchOnly()
    this.destroyMap()
  }

  retry() {
    if (this.green) this.beginWatch()
  }

  beginWatch() {
    this.stopWatchOnly()
    this.resetGpsFix()
    this.showLoading("Finding your location…")

    // Native apps: always bridge — never navigator.geolocation (avoids a second
    // WKWebView permission prompt while CoreLocation is also requesting).
    if (this.enabled || this.nativeApp) {
      this.beginNativeWatch()
    } else {
      this.beginWebWatch()
    }
  }

  // Stop GPS without tearing down the map (used when restarting the watch).
  stopWatchOnly() {
    this.clearNativeWatchTimeout()
    this.clearWarmupTimeout()

    if (this.enabled || this.nativeApp) {
      this.send("stop")
    } else if (this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId)
      this.watchId = null
    }
  }

  resetGpsFix() {
    this.clearWarmupTimeout()
    this.position = null
    this.accuracy = null
    this.gpsLocked = false
    this.gpsSamples = []
    this.gpsWarmupStartedAt = null
  }

  // Native path: ask the bridge to start streaming coordinates. The callback
  // fires on every native reply, mirroring watchPosition semantics. Messages
  // queue if the adapter is not attached yet.
  beginNativeWatch() {
    this.clearNativeWatchTimeout()
    this.nativeWatchTimeout = window.setTimeout(() => {
      if (!this.position) {
        this.showError("We couldn't find your location", "Check that Location is on, then try again.")
      }
    }, 15000)

    this.send("start", {}, (message) => {
      this.clearNativeWatchTimeout()
      const data = this.dataFrom(message)
      if (data.error) {
        this.onNativeError(data.error)
      } else if (typeof data.latitude === "number" && typeof data.longitude === "number") {
        this.onPosition({ coords: { latitude: data.latitude, longitude: data.longitude, accuracy: data.accuracy } })
      }
    })
  }

  clearNativeWatchTimeout() {
    if (this.nativeWatchTimeout) {
      clearTimeout(this.nativeWatchTimeout)
      this.nativeWatchTimeout = null
    }
  }

  beginWebWatch() {
    if (!("geolocation" in navigator)) {
      this.showError("Location is not available", "This device can't provide GPS for distances.")
      return
    }

    this.watchId = navigator.geolocation.watchPosition(
      (position) => this.onPosition(position),
      (error) => this.onError(error),
      { enableHighAccuracy: true, maximumAge: 2000, timeout: 27000 }
    )
  }

  onPosition(position) {
    const coords = position && position.coords
    if (!coords || typeof coords.latitude !== "number" || typeof coords.longitude !== "number") return

    const sample = {
      position: [coords.latitude, coords.longitude],
      accuracy: Number.isFinite(coords.accuracy) ? coords.accuracy : Infinity,
      at: Date.now()
    }

    if (!this.gpsLocked) {
      this.collectWarmupSample(sample)
      return
    }

    if (!this.shouldAcceptLockedSample(sample)) return
    this.applySample(sample)
  }

  collectWarmupSample(sample) {
    if (!this.gpsWarmupStartedAt) {
      this.gpsWarmupStartedAt = sample.at
      this.gpsSamples.push(sample)
      // Sharp first fix: paint immediately without a "warming up" flash.
      if (this.warmupReady()) {
        this.lockBestSample()
        return
      }
      this.showLoading("Getting a better GPS fix…")
      this.scheduleWarmupDeadline()
      return
    }

    this.gpsSamples.push(sample)
    if (this.warmupReady()) this.lockBestSample()
  }

  warmupReady() {
    if (!this.gpsWarmupStartedAt || this.gpsSamples.length === 0) return false

    const elapsed = Date.now() - this.gpsWarmupStartedAt
    const best = this.bestSample()
    if (best && best.accuracy <= GOOD_ACCURACY_M) return true
    if (this.gpsSamples.length >= MIN_WARMUP_SAMPLES && elapsed >= MIN_WARMUP_MS) return true
    if (elapsed >= MAX_WARMUP_MS) return true
    return false
  }

  bestSample() {
    if (!this.gpsSamples.length) return null

    return this.gpsSamples.reduce((best, sample) => (
      sample.accuracy < best.accuracy ? sample : best
    ))
  }

  lockBestSample() {
    const best = this.bestSample()
    if (!best) return

    this.clearWarmupTimeout()
    this.gpsLocked = true
    this.gpsSamples = []
    this.applySample(best)
  }

  scheduleWarmupDeadline() {
    this.clearWarmupTimeout()
    this.warmupTimeout = window.setTimeout(() => {
      if (!this.gpsLocked && this.gpsSamples.length > 0) this.lockBestSample()
    }, MAX_WARMUP_MS)
  }

  clearWarmupTimeout() {
    if (this.warmupTimeout) {
      clearTimeout(this.warmupTimeout)
      this.warmupTimeout = null
    }
  }

  shouldAcceptLockedSample(sample) {
    if (!this.position) return true

    const moved = haversineMeters(this.position, sample.position)
    if (moved >= MOVE_UPDATE_M) return true
    if (sample.accuracy <= this.accuracy - ACCURACY_IMPROVE_M) return true
    return false
  }

  applySample(sample) {
    this.position = sample.position
    this.accuracy = sample.accuracy
    this.render()
  }

  onError(error) {
    if (error && error.code === 1) {
      this.showError("Location access needed", "Enable location to see distances to the green.")
    } else {
      this.showError("We couldn't find your location", "Check that Location is on, then try again.")
    }
  }

  onNativeError(code) {
    if (code === "denied") {
      this.showError("Location access needed", "Enable location to see distances to the green.")
    } else {
      this.showError("We couldn't find your location", "Check that Location is on, then try again.")
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

  setView(event) {
    const value = event.currentTarget.dataset.value
    if (!value || value === this.view) return

    this.view = value
    this.syncViewButtons()
    this.syncViewVisibility()

    if (this.view === "map") {
      this.ensureMap()
      this.updateMap({ fit: true })
      this.scheduleMapResize()
    }
  }

  clearPivot() {
    this.pivot = null
    this.syncClearButton()
    if (this.distanceMap) {
      this.distanceMap.setPivot(null)
      this.distanceMap.fitCourse()
    }
  }

  render() {
    if (!this.green || !this.position) return

    const centerMeters = haversineMeters(this.position, this.green.centroid)
    if (centerMeters > TOO_FAR_METERS) {
      this.showState("tooFar")
      return
    }

    this.showState("content")
    this.centerTarget.textContent = this.value(centerMeters)
    this.frontTarget.textContent = this.value(nearestEdgeMeters(this.position, this.green.polygon))
    this.backTarget.textContent = this.value(farthestVertexMeters(this.position, this.green.polygon))

    if (this.hasAccuracyTarget) {
      this.accuracyTarget.textContent = this.accuracy
        ? `GPS accuracy ${this.convert(this.accuracy)} ${this.unitLabel}`
        : ""
    }

    if (this.view === "map") {
      this.ensureMap()
      this.updateMap({ fit: !this.didFitMap })
    }
  }

  ensureMap() {
    if (this.distanceMap || !this.hasMapContainerTarget) return

    // Size the container before Leaflet measures it (it was display:none).
    this.distanceMap = new DistanceMap(this.mapContainerTarget, {
      tileUrl: this.tileUrlValue,
      attribution: this.tileAttributionValue,
      formatDistance: (meters) => this.value(meters),
      onPivotChange: (pivot) => {
        this.pivot = pivot
        this.syncClearButton()
      }
    })

    if (this.green && this.green.centroid) this.distanceMap.setGreen(this.green.centroid)
    if (this.position) this.distanceMap.setUser(this.position)
    if (this.pivot) this.distanceMap.setPivot(this.pivot)
    this.distanceMap.invalidateSize()
    this.distanceMap.fitCourse()
    this.didFitMap = true
  }

  updateMap({ fit = false } = {}) {
    if (!this.distanceMap) return

    this.distanceMap.setFormatDistance((meters) => this.value(meters))
    if (this.green && this.green.centroid) this.distanceMap.setGreen(this.green.centroid)
    if (this.position) this.distanceMap.setUser(this.position)
    this.distanceMap.setPivot(this.pivot)
    this.syncClearButton()

    requestAnimationFrame(() => {
      if (!this.distanceMap) return
      this.distanceMap.invalidateSize()
      if (fit) {
        this.distanceMap.fitCourse()
        this.didFitMap = true
      }
    })
  }

  destroyMap() {
    if (this.mapResizeTimeout) {
      clearTimeout(this.mapResizeTimeout)
      this.mapResizeTimeout = null
    }
    if (this.distanceMap) {
      this.distanceMap.destroy()
      this.distanceMap = null
    }
    this.didFitMap = false
  }

  value(meters) {
    if (meters === null || Number.isNaN(meters)) return "—"
    return `${this.convert(meters)}`
  }

  convert(meters) {
    const value = this.unit === "m" ? meters : metersToYards(meters)
    return Math.round(value)
  }

  get unitLabel() {
    return this.unit === "m" ? "m" : "yds"
  }

  // Native replies may deliver data as an object or a JSON string.
  dataFrom(message) {
    const raw = message && message.data
    if (!raw) return {}
    if (typeof raw === "string") {
      try {
        return JSON.parse(raw)
      } catch {
        return {}
      }
    }
    return raw
  }

  syncUnitButtons() {
    if (!this.hasUnitOptionTarget) return

    this.unitOptionTargets.forEach((button) => {
      const active = button.dataset.value === this.unit
      button.dataset.state = active ? "active" : "inactive"
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  syncViewButtons() {
    if (!this.hasViewOptionTarget) return

    this.viewOptionTargets.forEach((button) => {
      const active = button.dataset.value === this.view
      button.dataset.state = active ? "active" : "inactive"
      button.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  syncViewVisibility() {
    if (this.hasNumbersTarget) {
      this.numbersTarget.dataset.state = this.view === "numbers" ? "active" : "inactive"
    }
    if (this.hasMapTarget) {
      this.mapTarget.dataset.state = this.view === "map" ? "active" : "inactive"
    }
  }

  // Leaflet measures a near-zero height while the panel is still growing; refit
  // after the grid-template-rows transition finishes (with a timeout fallback).
  scheduleMapResize() {
    if (this.mapResizeTimeout) clearTimeout(this.mapResizeTimeout)

    const resize = () => {
      if (!this.distanceMap || this.view !== "map") return
      this.distanceMap.invalidateSize()
      this.distanceMap.fitCourse()
      this.didFitMap = true
    }

    if (this.hasMapTarget) {
      const onEnd = (event) => {
        if (event.target !== this.mapTarget) return
        if (event.propertyName !== "grid-template-rows" && event.propertyName !== "opacity") return
        this.mapTarget.removeEventListener("transitionend", onEnd)
        if (this.mapResizeTimeout) clearTimeout(this.mapResizeTimeout)
        resize()
      }
      this.mapTarget.addEventListener("transitionend", onEnd)
    }

    this.mapResizeTimeout = setTimeout(resize, 250)
  }

  syncClearButton() {
    if (!this.hasClearPivotTarget) return
    this.toggle(this.clearPivotTarget, Boolean(this.pivot))
  }

  showLoading(message) {
    if (this.hasStatusLoadingMessageTarget) this.statusLoadingMessageTarget.textContent = message
    if (this.hasStatusLoadingTarget) this.toggle(this.statusLoadingTarget, true)
    if (this.hasStatusErrorTarget) this.toggle(this.statusErrorTarget, false)
    this.showState("status")
  }

  showError(title, message) {
    if (this.hasStatusErrorTitleTarget) this.statusErrorTitleTarget.textContent = title
    if (this.hasStatusErrorMessageTarget) {
      this.statusErrorMessageTarget.textContent = message || ""
      this.toggle(this.statusErrorMessageTarget, Boolean(message))
    }
    if (this.hasStatusLoadingTarget) this.toggle(this.statusLoadingTarget, false)
    if (this.hasStatusErrorTarget) this.toggle(this.statusErrorTarget, true)
    this.showState("status")
  }

  showState(which) {
    if (this.hasContentTarget) this.toggle(this.contentTarget, which === "content")
    if (this.hasStatusTarget) this.toggle(this.statusTarget, which === "status")
    if (this.hasEmptyTarget) this.toggle(this.emptyTarget, which === "empty")
    if (this.hasTooFarTarget) this.toggle(this.tooFarTarget, which === "tooFar")
    if (this.hasViewToggleTarget) this.toggle(this.viewToggleTarget, which === "content")

    if (which !== "content" && this.view === "map") {
      this.view = "numbers"
      this.syncViewButtons()
      this.syncViewVisibility()
    }
  }

  toggle(element, show) {
    element.classList.toggle("hidden", !show)
  }
}
