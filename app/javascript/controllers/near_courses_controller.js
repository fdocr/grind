// Requests GPS only when the user taps "Find courses near me", then loads
// nearby courses into the course_results Turbo Frame via ?lat=&lng=.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "status"]
  static values = { url: String }

  find(event) {
    event.preventDefault()

    if (!("geolocation" in navigator)) {
      this.showStatus("Location is not available on this device.")
      return
    }

    this.setBusy(true)
    this.showStatus("Finding your location…")

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
    this.setBusy(false)
    if (error && error.code === 1) {
      this.showStatus("Enable location access to find nearby courses.")
    } else {
      this.showStatus("We couldn't find your location. Try again.")
    }
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
