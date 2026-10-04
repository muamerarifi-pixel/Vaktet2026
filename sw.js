// Service worker: keeps the whole app available offline.
const CACHE = "vaktet-v18";
const ASSETS = [
  "/",
  "/index.html",
  "/styles.css",
  "/app.js",
  "/data.js",
  "/tips.js",
  "/manifest.webmanifest",
  "/fonts/figtree.woff2",
  "/fonts/Figtree.ttf",
  "/fonts/Nunito.ttf",
  "/fonts/Lora.ttf",
  "/fonts/JetBrainsMono.ttf",
  "/icons/favicon.svg",
  "/icons/icon-192.png",
  "/icons/icon-512.png",
  "/icons/icon-maskable-512.png",
  "/icons/apple-touch-icon.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(ASSETS.map((u) => new Request(u, { cache: "reload" })))).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Serve from cache first, refresh the cache in the background when online.
self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  const key = req.mode === "navigate" ? "/index.html" : req;

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const cached = await cache.match(key, { ignoreSearch: req.mode === "navigate" });
      const network = fetch(req)
        .then((res) => {
          if (res && res.ok && res.type === "basic") cache.put(key, res.clone());
          return res;
        })
        .catch(() => null);
      if (cached) {
        event.waitUntil(network);
        return cached;
      }
      const res = await network;
      return res || (req.mode === "navigate" ? cache.match("/index.html") : Response.error());
    })
  );
});
