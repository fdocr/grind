const CACHE_NAME = "grind-v4"
const OFFLINE_URLS = ["/icon.png", "/icon.svg", "/manifest.json", "/distances"]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(OFFLINE_URLS))
  )
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    ).then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return

  const url = new URL(event.request.url)
  if (url.origin !== self.location.origin) return

  if (url.pathname.startsWith("/assets/")) {
    event.respondWith(cacheFirst(event.request))
    return
  }

  if (OFFLINE_URLS.includes(url.pathname) || url.pathname === "/manifest.json" || url.pathname === "/distances") {
    event.respondWith(cacheFirst(event.request))
    return
  }

  if (event.request.mode === "navigate" || event.request.headers.get("Accept")?.includes("text/html")) {
    event.respondWith(networkFirst(event.request))
  }
})

function cacheFirst(request) {
  return caches.match(request).then((cached) => {
    if (cached) return cached

    return fetch(request).then((response) => {
      if (response.ok) {
        const copy = response.clone()
        caches.open(CACHE_NAME).then((cache) => cache.put(request, copy))
      }
      return response
    })
  })
}

function networkFirst(request) {
  return fetch(request)
    .then((response) => {
      if (response.ok) {
        const copy = response.clone()
        caches.open(CACHE_NAME).then((cache) => cache.put(request, copy))
      }
      return response
    })
    .catch(() => caches.match(request))
}
