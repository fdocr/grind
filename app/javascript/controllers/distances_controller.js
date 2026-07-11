import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { haversineMeters, nearestEdgeMeters, farthestVertexMeters, metersToYards } from "lib/geo"
import { DistanceMap } from "lib/leaflet_distance_map"

const STORAGE_KEY = "grind:distanceUnit"
const TOO_FAR_METERS = 800

// Live GPS distances to the front, center and back of the current hole's green.
// Green geometry is passed in from the round controller (embedded in the page),
// so this works offline. The math lives in lib/geo.js to stay testable.
//
// Map view (Numbers | Map) uses Leaflet satellite tiles with a red yardage line
// and an optional pivot that splits the shot into two segments.
//
// This is a Hotwire Native BridgeComponent named "geolocation". When running
// inside the native apps (which register the matching component) it streams
// high-accuracy coordinates from CoreLocation / FusedLocationProvider over the
// bridge, avoiding the WKWebView double permission prompt. In every other
// context (mobile/desktop browsers, PWA) it transparently falls back to
// navigator.geolocation.watchPosition, exactly as before.
export default class extends BridgeComponent {
  static component = "geolocation"
  static targets = [
    "front", "center", "back", "accuracy", "status", "statusMessage", "empty", "tooFar", "content",
    "unitOption", "numbers", "map", "mapContainer", "clearPivot", "viewOption", "viewToggle"
  ]
  static values = {
    unit: String,
    tileUrl: String,
    tileAttribution: String
  }

  // BridgeComponent gates loading on native support by default; force it to
  // always load so the browser fallback keeps working.
  static get shouldLoad() {
    return true
  }

  connect() {
    super.connect()
    this.unit = localStorage.getItem(STORAGE_KEY) || this.unitValue || "yds"
    this.green = null
    this.position = null
    this.accuracy = null
    this.watchId = null
    this.view = "numbers"
    this.pivot = null
    this.distanceMap = null
    this.didFitMap = false
    this.syncUnitButtons()
    this.syncViewButtons()
  }

  disconnect() {
    this.stop()
    super.disconnect()
  }

  // Called by the round controller when the Distances panel opens.
  start(detail) {
    this.green = (detail && detail.green) || null
    this.pivot = null
    this.view = "numbers"
    this.didFitMap = false
    this.destroyMap()
    this.syncViewButtons()
    this.syncViewVisibility()
    this.syncClearButton()

    if (!this.green || !Array.isArray(this.green.polygon) || this.green.polygon.length < 3) {
      this.stop()
      this.showState("empty")
      return
    }

    if (this.position) this.render()
    this.beginWatch()
  }

  stop() {
    if (this.enabled) {
      this.send("stop")
    } else if (this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId)
      this.watchId = null
    }
    this.destroyMap()
  }

  retry() {
    if (this.green) this.beginWatch()
  }

  beginWatch() {
    this.stopWatchOnly()
    if (!this.position) this.showStatus("Finding your location…")

    if (this.enabled) {
      this.beginNativeWatch()
    } else {
      this.beginWebWatch()
    }
  }

  // Stop GPS without tearing down the map (used when restarting the watch).
  stopWatchOnly() {
    if (this.enabled) {
      this.send("stop")
    } else if (this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId)
      this.watchId = null
    }
  }

  // Native path: ask the bridge to start streaming coordinates. The callback
  // fires on every native reply, mirroring watchPosition semantics.
  beginNativeWatch() {
    this.send("start", {}, (message) => {
      const data = this.dataFrom(message)
      if (data.error) {
        this.onNativeError(data.error)
      } else if (typeof data.latitude === "number" && typeof data.longitude === "number") {
        this.onPosition({ coords: { latitude: data.latitude, longitude: data.longitude, accuracy: data.accuracy } })
      }
    })
  }

  beginWebWatch() {
    if (!("geolocation" in navigator)) {
      this.showStatus("Location is not available on this device.")
      return
    }

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

  onNativeError(code) {
    if (code === "denied") {
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

  setView(event) {
    const value = event.currentTarget.dataset.value
    if (!value || value === this.view) return

    this.view = value
    this.syncViewButtons()
    this.syncViewVisibility()

    if (this.view === "map") {
      this.ensureMap()
      this.updateMap({ fit: true })
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
    if (this.hasNumbersTarget) this.toggle(this.numbersTarget, this.view === "numbers")
    if (this.hasMapTarget) this.toggle(this.mapTarget, this.view === "map")
  }

  syncClearButton() {
    if (!this.hasClearPivotTarget) return
    this.toggle(this.clearPivotTarget, Boolean(this.pivot))
  }

  showStatus(message) {
    if (this.hasStatusMessageTarget) this.statusMessageTarget.textContent = message
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
