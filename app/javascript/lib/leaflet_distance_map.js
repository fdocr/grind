// Leaflet wrapper for the round distances map view. Pinch zoom only (no pan);
// single-finger tap/drag places a pivot. Keeps map logic out of Stimulus.
import "leaflet"
import { haversineMeters } from "lib/geo"

const GREEN_COLOR = "#276f54"
const USER_COLOR = "#2563eb"
const LINE_COLOR = "#dc2626"
const PIVOT_COLOR = "#ffffff"

export class DistanceMap {
  constructor(element, { tileUrl, attribution, onPivotChange, formatDistance }) {
    const L = window.L
    this.L = L
    this.onPivotChange = onPivotChange
    this.formatDistance = formatDistance || ((meters) => String(Math.round(meters)))
    this.user = null
    this.green = null
    this.pivot = null
    this.suppressClick = false

    this.map = L.map(element, {
      zoomControl: true,
      dragging: false,
      doubleClickZoom: false,
      boxZoom: false,
      keyboard: false,
      scrollWheelZoom: true,
      touchZoom: true,
      tap: false
    }).setView([0, 0], 2)

    L.tileLayer(tileUrl, { attribution, maxZoom: 20 }).addTo(this.map)

    this.linesLayer = L.layerGroup().addTo(this.map)
    this.labelsLayer = L.layerGroup().addTo(this.map)

    this.userMarker = L.circleMarker([0, 0], {
      radius: 7,
      color: "#ffffff",
      fillColor: USER_COLOR,
      fillOpacity: 1,
      weight: 2
    })

    this.greenMarker = L.circleMarker([0, 0], {
      radius: 7,
      color: "#ffffff",
      fillColor: GREEN_COLOR,
      fillOpacity: 1,
      weight: 2
    })

    this.pivotMarker = L.marker([0, 0], {
      draggable: true,
      autoPan: false,
      icon: L.divIcon({
        className: "distance-map-div-icon",
        html: `<span style="display:block;width:16px;height:16px;border-radius:9999px;background:${PIVOT_COLOR};border:3px solid ${LINE_COLOR};box-shadow:0 1px 3px rgba(0,0,0,.4)"></span>`,
        iconSize: [16, 16],
        iconAnchor: [8, 8]
      })
    })

    this.map.on("click", (event) => {
      if (this.suppressClick) {
        this.suppressClick = false
        return
      }
      this.setPivot([event.latlng.lat, event.latlng.lng], { notify: true })
    })

    this.pivotMarker.on("drag", () => {
      const { lat, lng } = this.pivotMarker.getLatLng()
      this.pivot = [lat, lng]
      this.renderLines()
    })

    this.pivotMarker.on("dragend", () => {
      this.suppressClick = true
      const { lat, lng } = this.pivotMarker.getLatLng()
      this.setPivot([lat, lng], { notify: true, skipMarker: true })
    })
  }

  setUser(latlng) {
    this.user = latlng ? [latlng[0], latlng[1]] : null
    if (this.user) {
      this.userMarker.setLatLng(this.user)
      if (!this.map.hasLayer(this.userMarker)) this.userMarker.addTo(this.map)
    } else if (this.map.hasLayer(this.userMarker)) {
      this.map.removeLayer(this.userMarker)
    }
    this.ensureLoaded()
    this.renderLines()
  }

  setGreen(latlng) {
    this.green = latlng ? [latlng[0], latlng[1]] : null
    if (this.green) {
      this.greenMarker.setLatLng(this.green)
      if (!this.map.hasLayer(this.greenMarker)) this.greenMarker.addTo(this.map)
    } else if (this.map.hasLayer(this.greenMarker)) {
      this.map.removeLayer(this.greenMarker)
    }
    this.ensureLoaded()
    this.renderLines()
  }

  setPivot(latlng, { notify = false, skipMarker = false } = {}) {
    this.pivot = latlng ? [latlng[0], latlng[1]] : null

    if (this.pivot) {
      if (!skipMarker) this.pivotMarker.setLatLng(this.pivot)
      if (!this.map.hasLayer(this.pivotMarker)) this.pivotMarker.addTo(this.map)
    } else if (this.map.hasLayer(this.pivotMarker)) {
      this.map.removeLayer(this.pivotMarker)
    }

    this.ensureLoaded()
    this.renderLines()
    if (notify && this.onPivotChange) this.onPivotChange(this.pivot)
  }

  setFormatDistance(fn) {
    this.formatDistance = fn
    this.renderLines()
  }

  // Leaflet requires a view before layers/interactions are safe. Seed one from
  // whatever points we have so later setPivot/renderLines don't run unloaded.
  ensureLoaded() {
    if (this.map._loaded) return
    this.fitCourse()
  }

  fitCourse() {
    const L = this.L
    const points = []
    if (this.user) points.push(this.user)
    if (this.green) points.push(this.green)
    if (this.pivot) points.push(this.pivot)
    if (points.length === 0) return

    if (points.length === 1) {
      this.map.setView(points[0], 17)
      return
    }

    this.map.fitBounds(L.latLngBounds(points), { padding: [36, 36], maxZoom: 19 })
  }

  invalidateSize() {
    this.map.invalidateSize()
  }

  renderLines() {
    const L = this.L
    this.linesLayer.clearLayers()
    this.labelsLayer.clearLayers()

    if (!this.user || !this.green) return

    if (this.pivot) {
      this.addSegment(this.user, this.pivot)
      this.addSegment(this.pivot, this.green)
    } else {
      this.addSegment(this.user, this.green)
    }
  }

  addSegment(from, to) {
    const L = this.L
    L.polyline([from, to], {
      color: LINE_COLOR,
      weight: 3,
      opacity: 0.95
    }).addTo(this.linesLayer)

    const meters = haversineMeters(from, to)
    const mid = [(from[0] + to[0]) / 2, (from[1] + to[1]) / 2]
    L.marker(mid, {
      interactive: false,
      keyboard: false,
      icon: L.divIcon({
        className: "distance-map-div-icon",
        html: `<span class="distance-map-label" style="transform:translate(-50%,-50%)">${this.formatDistance(meters)}</span>`,
        iconSize: [0, 0],
        iconAnchor: [0, 0]
      })
    }).addTo(this.labelsLayer)
  }

  destroy() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }
}
