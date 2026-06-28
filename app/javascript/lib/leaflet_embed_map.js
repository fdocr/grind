// Read-only satellite map embed for admin previews. No zoom controls or panning.
import "leaflet"

export function createEmbedMap(element, { center, zoom = 16, tileUrl, attribution }) {
  const L = window.L

  const map = L.map(element, {
    zoomControl: false,
    dragging: false,
    scrollWheelZoom: false,
    doubleClickZoom: false,
    boxZoom: false,
    keyboard: false,
    touchZoom: false,
    tap: false
  }).setView(center, zoom)

  L.tileLayer(tileUrl, { attribution, maxZoom: 20 }).addTo(map)
  L.circleMarker(center, {
    radius: 6,
    color: "#276f54",
    fillColor: "#276f54",
    fillOpacity: 1,
    weight: 2
  }).addTo(map)

  return map
}
