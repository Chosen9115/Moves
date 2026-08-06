// Moves service worker — offline shell + static-asset caching.
//
// SECURITY: this worker NEVER caches HTML. Authenticated pages must not be
// stored and replayed after logout/session expiry, so only fingerprinted static
// assets (CSS/JS/images/fonts) are cached; page navigations always hit the
// network and fall back to a generic offline shell when truly offline.
//
// Bump CACHE_VERSION when the shell/assets change so old caches are purged.
const CACHE_PREFIX = "moves-";
const CACHE = `${CACHE_PREFIX}v1`;
const PRECACHE = [
  "/offline.html",
  "/manifest.json",
  "/icons/icon-192.png",
  "/icons/icon-512.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      // Only evict THIS app's old caches, never other apps' on the same origin.
      .then((keys) => Promise.all(
        keys.filter((k) => k.startsWith(CACHE_PREFIX) && k !== CACHE).map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

const STATIC_DESTINATIONS = ["style", "script", "image", "font"];

function isStaticAsset(request, url) {
  return STATIC_DESTINATIONS.includes(request.destination) ||
    url.pathname.startsWith("/assets/") ||
    url.pathname.startsWith("/icons/");
}

self.addEventListener("fetch", (event) => {
  const { request } = event;

  // Never touch non-GET (mutations) or cross-origin, and never the API.
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname === "/api" || url.pathname.startsWith("/api/")) return;

  // Real browser navigations (document loads): network only, with an offline
  // SHELL fallback — never a cached authenticated page.
  if (request.mode === "navigate" || request.destination === "document") {
    event.respondWith(fetch(request).catch(() => caches.match("/offline.html")));
    return;
  }

  // Static assets only: cache-first, then network (cache successful,
  // non-redirected responses so a login-redirect can't be pinned).
  if (isStaticAsset(request, url)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached;
        return fetch(request)
          .then((response) => {
            if (response && response.ok && !response.redirected) {
              const copy = response.clone();
              event.waitUntil(caches.open(CACHE).then((cache) => cache.put(request, copy)));
            }
            return response;
          })
          .catch(() => cached);
      })
    );
    return;
  }

  // Everything else (incl. Turbo Drive's HTML page fetches): straight to the
  // network, never cached — the browser default (no respondWith).
});
