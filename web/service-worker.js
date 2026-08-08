// Offline-first service worker. Caches the whole app shell so Block Grid runs
// with no network at all once installed to the home screen.
const CACHE = 'block-grid-v3';

const ASSETS = [
  './',
  './index.html',
  './styles.css',
  './manifest.webmanifest',
  './js/main.js',
  './js/scene.js',
  './js/engine.js',
  './js/board.js',
  './js/shapes.js',
  './js/scoring.js',
  './js/generator.js',
  './js/skins.js',
  './js/color.js',
  './js/textures.js',
  './js/audio.js',
  './js/storage.js',
  './icons/icon-180.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))),
    ).then(() => self.clients.claim()),
  );
});

// Cache-first for same-origin assets; network for everything else (fonts).
self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);

  if (url.origin === location.origin) {
    event.respondWith(
      caches.match(request).then((cached) => cached || fetch(request).then((resp) => {
        const copy = resp.clone();
        caches.open(CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
        return resp;
      }).catch(() => cached)),
    );
    return;
  }

  // Cross-origin (Google Fonts): stale-while-revalidate.
  event.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request).then((resp) => {
        const copy = resp.clone();
        caches.open(CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
        return resp;
      }).catch(() => cached);
      return cached || network;
    }),
  );
});
