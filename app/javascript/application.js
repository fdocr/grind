// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Strip the course picker modal before Turbo caches the homepage so a native
// back navigation does not restore the popover over the course list.
document.addEventListener("turbo:before-cache", () => {
  document.getElementById("course_modal")?.replaceChildren()
})

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker")
  })
}
