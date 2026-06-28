// Leaflet wrapper for admin green tracing. Keeps map logic out of Stimulus.
import "leaflet"

export class GreenMap {
  constructor(element, { center, zoom = 18, tileUrl, attribution, onVertexAdd, onMoveEnd }) {
    const L = window.L
    this.L = L
    this.onVertexAdd = onVertexAdd
    this.onMoveEnd = onMoveEnd
    this.vertices = []

    this.map = L.map(element, { zoomControl: true }).setView(center, zoom)
    L.tileLayer(tileUrl, { attribution, maxZoom: 20 }).addTo(this.map)

    this.polygonLayer = L.polygon([], { color: "#276f54", fillOpacity: 0.25, weight: 2 }).addTo(this.map)
    this.markersLayer = L.layerGroup().addTo(this.map)

    this.map.on("click", (event) => {
      if (this.onVertexAdd) this.onVertexAdd([ event.latlng.lat, event.latlng.lng ])
    })

    if (onMoveEnd) {
      this.map.on("moveend", () => onMoveEnd(this.getViewport()))
    }
  }

  setVertices(vertices) {
    this.vertices = Array.isArray(vertices) ? vertices.map((vertex) => [ vertex[0], vertex[1] ]) : []
    this.render()
  }

  addVertex(latlng) {
    this.vertices.push([ latlng[0], latlng[1] ])
    this.render()
  }

  undo() {
    this.vertices.pop()
    this.render()
  }

  clear() {
    this.vertices = []
    this.render()
  }

  getPolygon() {
    return this.vertices.map((vertex) => [ vertex[0], vertex[1] ])
  }

  getViewport() {
    const bounds = this.map.getBounds()
    return {
      bbox: [ bounds.getWest(), bounds.getSouth(), bounds.getEast(), bounds.getNorth() ],
      zoom: this.map.getZoom()
    }
  }

  flyTo(center, zoom) {
    if (!center) return
    this.map.flyTo(center, zoom || this.map.getZoom())
  }

  render() {
    const L = this.L
    this.markersLayer.clearLayers()

    this.vertices.forEach((vertex) => {
      L.circleMarker(vertex, {
        radius: 5,
        color: "#276f54",
        fillColor: "#276f54",
        fillOpacity: 1,
        weight: 2
      }).addTo(this.markersLayer)
    })

    if (this.vertices.length >= 3) {
      this.polygonLayer.setLatLngs(this.vertices)
    } else {
      this.polygonLayer.setLatLngs([])
    }
  }
}
