
// Registered automatically by SvelteKit. Its main job is to make the site
// installable as an app; it caches only the built app files and lets
// everything else (API, ActionCable, video) go straight to the network.
import { immutable, assets } from '$app/manifest';
import { version } from '$app/env';

const sw = self as unknown as ServiceWorkerGlobalScope;

const CACHE = `pool-tv-${version}`;
// Manifest paths are relative to the base path ('' here), so make them absolute.
const ASSETS = new Set(
	[...immutable, ...assets].map(({ path }) => (path.startsWith('/') ? path : `/${path}`))
);

sw.addEventListener('install', (event) => {
	event.waitUntil(
		caches
			.open(CACHE)
			.then((cache) => cache.addAll([...ASSETS]))
			.then(() => sw.skipWaiting())
	);
});

sw.addEventListener('activate', (event) => {
	event.waitUntil(
		caches
			.keys()
			.then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
			.then(() => sw.clients.claim())
	);
});

sw.addEventListener('fetch', (event) => {
	if (event.request.method !== 'GET') return;

	const url = new URL(event.request.url);
	if (url.origin !== sw.location.origin || !ASSETS.has(url.pathname)) return;

	event.respondWith(
		caches.match(url.pathname).then((cached) => cached ?? fetch(event.request))
	);
});
