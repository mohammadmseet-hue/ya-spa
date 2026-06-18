/* Ya Spa service worker — offline + installable PWA */
const CACHE = 'yaspa-v2';
const CORE = [
  './',
  './index.html',
  './assets/styles.css',
  './assets/app.js',
  './assets/logo.svg',
  './assets/icon.svg',
  './assets/icon-192.png',
  './assets/icon-512.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  // Network-first for navigations (fresh content), fallback to cached shell offline
  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).then(r => { const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); return r; })
      .catch(() => caches.match('./index.html')));
    return;
  }
  // Cache-first for static assets
  e.respondWith(caches.match(req).then(cached => cached || fetch(req).then(r => {
    const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); return r;
  }).catch(() => cached)));
});
