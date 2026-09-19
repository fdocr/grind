// Leaflet wrapper for the round distances map view. Pinch zoom only (no pan);
// single-finger tap/drag places a pivot. Keeps map logic out of Stimulus.
//
// The map is rotated so the player sits at the bottom of the view and the
// green is at the top (hole-up), instead of locking to true north.
import "leaflet"
import { haversineMeters, initialBearingDegrees } from "lib/geo"

const GREEN_COLOR = "#276f54"
const USER_COLOR = "#2563eb"
const LINE_COLOR = "#dc2626"
const PIVOT_COLOR = "#ffffff"
const FIT_PADDING_PX = 36
const MAX_FIT_ZOOM = 19
// Wait out the mobile delayed-click after Numbers→Map finishes expanding.
const CLICK_ARM_AFTER_RESIZE_MS = 400
// If the host never reports a resize (already-visible map), still arm taps.
const CLICK_ARM_FALLBACK_MS = 1000
// Smallest square that still covers the clip after any heading (45° is worst).
const ROTATOR_SIZE = `${Math.SQRT2 * 100}%`

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
    this.headingDegrees = 0
    this.pivotDrag = null
    this.fitted = false

    this.clip = element
    this.clip.classList.add("distance-map-clip")
    this.clip.style.clipPath = "inset(0)"
    this.clip.dataset.hasPivot = "false"
    this.clicksArmed = false
    this.armClicksAfter(CLICK_ARM_FALLBACK_MS)

    this.rotator = document.createElement("div")
    this.rotator.className = "distance-map-rotator"
    this.rotator.style.position = "absolute"
    this.rotator.style.left = "50%"
    this.rotator.style.top = "50%"
    this.rotator.style.transformOrigin = "center center"
    this.rotator.style.width = ROTATOR_SIZE
    this.rotator.style.height = ROTATOR_SIZE
    this.applyHeadingTransform()
    this.rotator.dataset.heading = "0.00"
    this.clip.appendChild(this.rotator)

    this.map = L.map(this.rotator, {
      zoomControl: true,
      dragging: false,
      doubleClickZoom: false,
      boxZoom: false,
      keyboard: false,
      scrollWheelZoom: true,
      touchZoom: true,
      tap: false
    }).setView([0, 0], 2)

    // Pointer math must use the unrotated rotator, not the clip's AABB.
    this.map.mouseEventToContainerPoint = (event) => this.pointerToRotatorPoint(event)

    // Keep zoom/attribution upright; they would otherwise spin with the tiles.
    this.controlContainer = this.map.getContainer().querySelector(".leaflet-control-container")
    if (this.controlContainer) this.clip.appendChild(this.controlContainer)

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
      draggable: false,
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
      if (!this.clicksArmed) return
      this.setPivot([event.latlng.lat, event.latlng.lng], { notify: true })
    })

    this.pivotMarker.on("mousedown", (event) => this.beginPivotDrag(event))
    this.pivotMarker.on("touchstart", (event) => this.beginPivotDrag(event))
  }

  setUser(latlng) {
    this.user = latlng ? [latlng[0], latlng[1]] : null
    if (this.user) {
      this.userMarker.setLatLng(this.user)
      if (!this.map.hasLayer(this.userMarker)) this.userMarker.addTo(this.map)
    } else if (this.map.hasLayer(this.userMarker)) {
      this.map.removeLayer(this.userMarker)
    }
    this.syncHeading()
    this.ensureLoaded()
    this.renderLines()
    this.keepHoleUpFrame()
  }

  setGreen(latlng) {
    this.green = latlng ? [latlng[0], latlng[1]] : null
    if (this.green) {
      this.greenMarker.setLatLng(this.green)
      if (!this.map.hasLayer(this.greenMarker)) this.greenMarker.addTo(this.map)
    } else if (this.map.hasLayer(this.greenMarker)) {
      this.map.removeLayer(this.greenMarker)
    }
    this.syncHeading()
    this.ensureLoaded()
    this.renderLines()
    this.keepHoleUpFrame()
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
    this.clip.dataset.hasPivot = this.pivot ? "true" : "false"
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
    this.syncHeading()

    const points = this.fitPoints()
    if (points.length === 0) return

    if (points.length === 1) {
      this.map.setView(points[0], 17)
      this.markFitted()
      return
    }

    if (this.fitHeadingAligned(points)) this.markFitted()
  }

  invalidateSize() {
    this.map.invalidateSize()
  }

  armClicks() {
    if (this.armClicksTimeout) {
      clearTimeout(this.armClicksTimeout)
      this.armClicksTimeout = null
    }
    this.clicksArmed = true
  }

  armClicksAfter(delayMs = CLICK_ARM_AFTER_RESIZE_MS) {
    if (this.armClicksTimeout) clearTimeout(this.armClicksTimeout)
    this.armClicksTimeout = window.setTimeout(() => this.armClicks(), delayMs)
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
    const upright = -this.headingDegrees
    L.marker(mid, {
      interactive: false,
      keyboard: false,
      icon: L.divIcon({
        className: "distance-map-div-icon",
        html: `<span class="distance-map-label" style="transform:translate(-50%,-50%) rotate(${upright}deg)">${this.formatDistance(meters)}</span>`,
        iconSize: [0, 0],
        iconAnchor: [0, 0]
      })
    }).addTo(this.labelsLayer)
  }

  destroy() {
    this.endPivotDrag()
    if (this.armClicksTimeout) {
      clearTimeout(this.armClicksTimeout)
      this.armClicksTimeout = null
    }
    if (this.map) {
      this.map.remove()
      this.map = null
    }
    if (this.controlContainer) {
      this.controlContainer.remove()
      this.controlContainer = null
    }
    this.rotator = null
  }

  fitPoints() {
    const points = []
    if (this.user) points.push(this.user)
    if (this.green) points.push(this.green)
    if (this.pivot) points.push(this.pivot)
    return points
  }

  // CSS-rotate the expanded map so player→green points up. Fit in that
  // heading so both markers stay inside the visible clip, not the larger rotator.
  syncHeading() {
    const heading = (this.user && this.green) ? -initialBearingDegrees(this.user, this.green) : 0
    if (heading === this.headingDegrees && this.rotator) {
      return heading
    }

    this.headingDegrees = heading
    this.applyHeadingTransform()
    if (this.rotator) this.rotator.dataset.heading = heading.toFixed(2)
    return heading
  }

  applyHeadingTransform() {
    if (!this.rotator) return
    this.rotator.style.transform = `translate(-50%, -50%) rotate(${this.headingDegrees}deg)`
  }

  // After the first fit, GPS updates keep the player at the bottom and the
  // green at the top without changing zoom (pinch stays put).
  keepHoleUpFrame() {
    if (!this.fitted) return
    const points = this.fitPoints()
    if (points.length < 2) return
    this.fitHeadingAligned(points, { changeZoom: false })
  }

  fitHeadingAligned(points, { changeZoom = true } = {}) {
    const view = this.headingAlignedView(points)
    if (!view) return false

    const zoom = changeZoom ? view.suggestedZoom : this.map.getZoom()
    this.map.setView(view.center, zoom, { animate: false })
    return true
  }

  headingAlignedView(points) {
    const L = this.L
    const clipW = this.clip.clientWidth
    const clipH = this.clip.clientHeight
    if (clipW < 8 || clipH < 8) return null

    const availW = Math.max(clipW - FIT_PADDING_PX * 2, 1)
    const availH = Math.max(clipH - FIT_PADDING_PX * 2, 1)
    const theta = (this.headingDegrees * Math.PI) / 180
    const refZoom = 18
    const projected = points.map((point) => this.map.project(L.latLng(point[0], point[1]), refZoom))
    const rotated = projected.map((point) => rotatePoint(point.x, point.y, theta))

    let minX = Infinity
    let minY = Infinity
    let maxX = -Infinity
    let maxY = -Infinity
    rotated.forEach(([x, y]) => {
      if (x < minX) minX = x
      if (y < minY) minY = y
      if (x > maxX) maxX = x
      if (y > maxY) maxY = y
    })

    const [centerX, centerY] = rotatePoint((minX + maxX) / 2, (minY + maxY) / 2, -theta)
    const spanX = Math.max(maxX - minX, 1)
    const spanY = Math.max(maxY - minY, 1)
    const zoomX = refZoom + Math.log2(availW / spanX)
    const zoomY = refZoom + Math.log2(availH / spanY)
    const zoomSnap = this.map.options.zoomSnap || 1

    return {
      center: this.map.unproject(L.point(centerX, centerY), refZoom),
      suggestedZoom: Math.min(MAX_FIT_ZOOM, Math.max(0, Math.floor(Math.min(zoomX, zoomY) / zoomSnap) * zoomSnap))
    }
  }

  markFitted() {
    this.fitted = true
    if (this.rotator) this.rotator.dataset.fitted = "true"
  }

  pointerToRotatorPoint(event) {
    const L = this.L
    const rect = this.clip.getBoundingClientRect()
    const dx = event.clientX - rect.left - rect.width / 2
    const dy = event.clientY - rect.top - rect.height / 2
    const [x, y] = rotatePoint(dx, dy, -(this.headingDegrees * Math.PI) / 180)
    return L.point(x + this.rotator.clientWidth / 2, y + this.rotator.clientHeight / 2)
  }

  beginPivotDrag(event) {
    const original = event.originalEvent || event
    if (original.touches && original.touches.length > 1) return

    this.L.DomEvent.preventDefault(original)
    this.L.DomEvent.stopPropagation(original)
    this.endPivotDrag()
    this.suppressClick = true

    const pointEvent = (next) => (
      (next.touches && next.touches[0]) ||
      (next.changedTouches && next.changedTouches[0]) ||
      next
    )

    const onMove = (next) => {
      const source = pointEvent(next)
      if (!source || typeof source.clientX !== "number") return
      if (next.cancelable) next.preventDefault()
      const latlng = this.map.mouseEventToLatLng(source)
      this.pivot = [latlng.lat, latlng.lng]
      this.pivotMarker.setLatLng(latlng)
      this.renderLines()
    }

    const onUp = () => {
      this.endPivotDrag()
      const { lat, lng } = this.pivotMarker.getLatLng()
      this.setPivot([lat, lng], { notify: true, skipMarker: true })
    }

    this.pivotDrag = { move: onMove, up: onUp }
    document.addEventListener("mousemove", onMove)
    document.addEventListener("mouseup", onUp)
    document.addEventListener("touchmove", onMove, { passive: false })
    document.addEventListener("touchend", onUp)
    document.addEventListener("touchcancel", onUp)
    onMove(original)
  }

  endPivotDrag() {
    if (!this.pivotDrag) return
    document.removeEventListener("mousemove", this.pivotDrag.move)
    document.removeEventListener("mouseup", this.pivotDrag.up)
    document.removeEventListener("touchmove", this.pivotDrag.move)
    document.removeEventListener("touchend", this.pivotDrag.up)
    document.removeEventListener("touchcancel", this.pivotDrag.up)
    this.pivotDrag = null
  }
}

function rotatePoint(x, y, radians) {
  const cos = Math.cos(radians)
  const sin = Math.sin(radians)
  return [x * cos - y * sin, x * sin + y * cos]
}
