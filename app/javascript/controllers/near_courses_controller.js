// Requests GPS only when the user taps "Find courses near me", then loads
// nearby courses into the course_results Turbo Frame via ?lat=&lng=.
//
// Hotwire Native: use the "geolocation" bridge (same as Distances) so WKWebView
// never shows a second website location prompt. Browsers/PWA keep using
// navigator.geolocation.
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "geolocation"
  static targets = ["button", "status"]
  static values = { url: String }

  static get shouldLoad() {
    return true
  }

  get nativeApp() {
    const { bridgePlatform, bridgeComponents } = document.documentElement.dataset
    if (bridgePlatform || (bridgeComponents && bridgeComponents.includes("geolocation"))) return true

    const ua = navigator.userAgent || ""
    return /\bHotwire Native\b/i.test(ua) || /bridge-components:\s*\[[^\]]*geolocation/.test(ua)
  }

  find(event) {
    event.preventDefault()
    this.clearLocateTimeout()

    this.setBusy(true)
    this.showStatus("Finding your location…")

    if (this.enabled || this.nativeApp) {
      this.beginNativeLocate()
    } else {
      this.beginWebLocate()
    }
  }

  beginNativeLocate() {
    let settled = false

    this.locateTimeout = window.setTimeout(() => {
      if (settled) return
      settled = true
      this.send("stop")
      this.onLocateFailed("unavailable")
    }, 15000)

    this.send("start", {}, (message) => {
      if (settled) return

      const data = this.dataFrom(message)
      if (data.error) {
        settled = true
        this.clearLocateTimeout()
        this.send("stop")
        this.onLocateFailed(data.error)
        return
      }

      if (typeof data.latitude === "number" && typeof data.longitude === "number") {
        settled = true
        this.clearLocateTimeout()
        this.send("stop")
        this.onPosition({
          coords: {
            latitude: data.latitude,
            longitude: data.longitude,
            accuracy: data.accuracy
          }
        })
      }
    })
  }

  beginWebLocate() {
    if (!("geolocation" in navigator)) {
      this.onLocateFailed("unavailable")
      return
    }

    navigator.geolocation.getCurrentPosition(
      (position) => this.onPosition(position),
      (error) => this.onError(error),
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 }
    )
  }

  onPosition(position) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("lat", position.coords.latitude)
    url.searchParams.set("lng", position.coords.longitude)

    this.showStatus("")
    this.setBusy(false)
    Turbo.visit(`${url.pathname}${url.search}`, { frame: "course_results" })
  }

  onError(error) {
    if (error && error.code === 1) {
      this.onLocateFailed("denied")
    } else {
      this.onLocateFailed("unavailable")
    }
  }

  onLocateFailed(code) {
    this.setBusy(false)
    if (code === "denied") {
      this.showStatus("Enable location access to find nearby courses.")
    } else {
      this.showStatus("We couldn't find your location. Try again.")
    }
  }

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

  clearLocateTimeout() {
    if (this.locateTimeout) {
      clearTimeout(this.locateTimeout)
      this.locateTimeout = null
    }
  }

  disconnect() {
    this.clearLocateTimeout()
    if (this.enabled || this.nativeApp) this.send("stop")
    super.disconnect()
  }

  setBusy(busy) {
    if (!this.hasButtonTarget) return
    this.buttonTarget.disabled = busy
  }

  showStatus(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("hidden", message.length === 0)
  }
}
