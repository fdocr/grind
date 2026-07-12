// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

function clearCourseModal() {
  document.querySelectorAll("[data-modal-portal]").forEach((node) => node.remove())
  document.getElementById("course_modal")?.replaceChildren()
  document.documentElement.classList.remove("overflow-hidden")
}

function clearNavMenus() {
  document.querySelectorAll("[data-nav-menu-target='menu']").forEach((menu) => {
    menu.classList.add("hidden")
    menu.setAttribute("aria-hidden", "true")
  })
  document.querySelectorAll("[data-nav-menu-target='button']").forEach((button) => {
    button.setAttribute("aria-expanded", "false")
  })
}

function clearTransientUi() {
  clearCourseModal()
  clearNavMenus()
}

function courseModalHasElementContent() {
  const frame = document.getElementById("course_modal")
  if (!frame) return false
  return Array.from(frame.childNodes).some((node) => node.nodeType === Node.ELEMENT_NODE)
}

// Strip transient overlays before Turbo caches a page so Native back does not
// restore an open course preview or nav menu over the destination.
document.addEventListener("turbo:before-cache", clearTransientUi)

// BFCache / Native back can restore a snapshot that skipped turbo:before-cache.
window.addEventListener("pageshow", (event) => {
  if (event.persisted) clearTransientUi()
})

document.addEventListener("turbo:load", () => {
  // Drop any orphaned portaled modal left behind after a full-page visit.
  // A portal leaves only a comment placeholder in the frame — treat that as empty.
  if (!courseModalHasElementContent()) {
    document.querySelectorAll("[data-modal-portal]").forEach((node) => node.remove())
    document.documentElement.classList.remove("overflow-hidden")
  }

  clearNavMenus()

  // Round tracker is a full page; clear Turbo snapshots so Native back does not
  // revive a homepage with the preview still open.
  if (document.querySelector("[data-controller~='round']")) {
    Turbo.clearCache()
  }
})

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker")
  })
}
