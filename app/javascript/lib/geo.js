// Pure geo helpers for live distance calculations. Decoupled from any Stimulus
// controller so the math stays small and testable. Coordinates are [lat, lng].

const EARTH_RADIUS_M = 6371000
const YARDS_PER_METER = 1.0936132983

export function haversineMeters(a, b) {
  const lat1 = (a[0] * Math.PI) / 180
  const lat2 = (b[0] * Math.PI) / 180
  const dLat = lat2 - lat1
  const dLng = ((b[1] - a[1]) * Math.PI) / 180
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h))
}

// Distance to the nearest point on the green outline (front edge).
export function nearestEdgeMeters(point, ring) {
  if (!Array.isArray(ring) || ring.length === 0) return null

  const local = ring.map((vertex) => toLocalXY(point, vertex))
  if (local.length === 1) return Math.hypot(local[0][0], local[0][1])

  const origin = [0, 0]
  let min = Infinity
  for (let i = 0; i < local.length; i++) {
    const a = local[i]
    const b = local[(i + 1) % local.length]
    const distance = distanceToSegment(origin, a, b)
    if (distance < min) min = distance
  }
  return min
}

// Distance to the farthest green vertex (back edge).
export function farthestVertexMeters(point, ring) {
  if (!Array.isArray(ring) || ring.length === 0) return null

  let max = 0
  ring.forEach((vertex) => {
    const distance = haversineMeters(point, vertex)
    if (distance > max) max = distance
  })
  return max
}

export function metersToYards(meters) {
  return meters * YARDS_PER_METER
}

// Equirectangular projection to local meters, relative to origin [lat, lng].
function toLocalXY(origin, point) {
  const lat0 = (origin[0] * Math.PI) / 180
  const x = ((point[1] - origin[1]) * Math.PI / 180) * Math.cos(lat0) * EARTH_RADIUS_M
  const y = ((point[0] - origin[0]) * Math.PI / 180) * EARTH_RADIUS_M
  return [x, y]
}

function distanceToSegment(p, a, b) {
  const dx = b[0] - a[0]
  const dy = b[1] - a[1]
  const lengthSq = dx * dx + dy * dy
  if (lengthSq === 0) return Math.hypot(p[0] - a[0], p[1] - a[1])

  let t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / lengthSq
  t = Math.max(0, Math.min(1, t))
  const projX = a[0] + t * dx
  const projY = a[1] + t * dy
  return Math.hypot(p[0] - projX, p[1] - projY)
}
