// CRPC Choir Songbook service worker: keeps the songbook usable offline.
// The version below is stamped automatically on every `quarto render`.
const VERSION = "20261003220320";
const CACHE = "crpc-songbook-" + VERSION;
const BASE = new URL("./", self.location).href;
const AUDIO = /\.(mp3|m4a|aac|wav|ogg)$/i;
const ASSET = /\.(css|js|png|jpe?g|svg|gif|webp|ico|woff2?|ttf|json|webmanifest)$/i;
const NET_TIMEOUT_MS = 4000;  // slow network: fall back to the saved copy after 4 s

self.addEventListener("install", (event) => {
  self.skipWaiting();
  event.waitUntil(precacheEverything());
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys())
      if (key.startsWith("crpc-songbook-") && key !== CACHE) await caches.delete(key);
    await self.clients.claim();
  })());
});

// Save every page listed in Quarto's search index, plus the CSS/JS/images they use.
// Audio is left out on purpose so phones don't fill up.
async function precacheEverything() {
  const cache = await caches.open(CACHE);
  const pages = new Set([BASE, BASE + "index.html"]);
  const assets = new Set([BASE + "search.json", BASE + "listings.json", BASE + "manifest.webmanifest"]);
  try {
    const res = await fetch(BASE + "search.json", { cache: "no-store" });
    for (const item of await res.json())
      if (item.href) pages.add(new URL(item.href.split("#")[0], BASE).href);
  } catch (e) { /* offline during install: pages are saved as they are visited */ }

  const list = [...pages];
  for (let i = 0; i < list.length; i += 6) {
    await Promise.all(list.slice(i, i + 6).map(async (url) => {
      try {
        const res = await fetch(url, { cache: "no-store" });
        if (!res.ok) return;
        const html = await res.clone().text();
        await cache.put(url, res);
        for (const m of html.matchAll(/(?:href|src)="([^"#]+)"/g)) {
          const u = new URL(m[1], url);
          if (u.href.startsWith(BASE) && ASSET.test(u.pathname)) assets.add(u.href);
        }
      } catch (e) { /* skip this page */ }
    }));
  }
  await Promise.all([...assets].map((a) => cache.add(a).catch(() => {})));
}

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET" || req.headers.has("range")) return;
  const url = new URL(req.url);
  if (AUDIO.test(url.pathname)) return;                       // audio: always from the network
  if (url.href.startsWith(BASE)) {
    event.respondWith(req.mode === "navigate" ? pageFirstFromNetwork(event) : savedThenRefresh(req));
  } else if (/^fonts\.(googleapis|gstatic)\.com$/.test(url.hostname)) {
    event.respondWith(savedThenRefresh(req));
  }
});

// Pages: try the network (so updates show), use the saved copy if offline or slow.
async function pageFirstFromNetwork(event) {
  const req = event.request;
  const cache = await caches.open(CACHE);
  const network = fetch(req).then((res) => {
    if (res.ok) cache.put(req, res.clone());
    return res;
  });
  event.waitUntil(network.catch(() => {}));
  const saved = () => findSaved(cache, req.url);
  try {
    return await Promise.race([
      network,
      new Promise((resolve, reject) => setTimeout(async () => {
        const hit = await saved();
        hit ? resolve(hit) : reject();
      }, NET_TIMEOUT_MS)),
    ]);
  } catch (e) {
    return (await saved()) || offlinePage();
  }
}

async function findSaved(cache, href) {
  const u = new URL(href); u.search = ""; u.hash = "";
  return (await cache.match(u.href)) ||
         (u.pathname.endsWith("/") ? await cache.match(u.href + "index.html") : undefined);
}

// Styles, scripts, images, fonts: answer instantly from the saved copy, refresh in the background.
async function savedThenRefresh(req) {
  const cache = await caches.open(CACHE);
  const hit = await cache.match(req, { ignoreSearch: true });
  const network = fetch(req).then((res) => {
    if (res && (res.ok || res.type === "opaque")) cache.put(req, res.clone());
    return res;
  }).catch(() => hit);
  return hit || network;
}

function offlinePage() {
  return new Response(
    '<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>Offline</title><body style="font-family:system-ui,sans-serif;padding:2rem;color:#1A1A1A;background:#FBFBF8">' +
    '<h1 style="color:#1F3A2E">You are offline</h1>' +
    '<p>This page has not been saved on your phone yet. Go back to the <a href="' + BASE + 'index.html">song list</a>; ' +
    'songs you can see there are available offline.</p></body>',
    { headers: { "Content-Type": "text/html; charset=utf-8" } });
}
