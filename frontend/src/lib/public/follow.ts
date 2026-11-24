import { subscribe, type LiveStatus } from '../cable.ts';

/**
 * Keeps a public page live: loads it, then reloads on every change pushed for it and on
 * every reconnect (so nothing is missed). Changes come in bursts (a result moves several
 * fixtures), so they are gathered into one reload. Use inside $effect.
 */
export function follow(
	kind: 'match' | 'tournament',
	token: string,
	load: () => Promise<void>,
	handlers: { onStatus: (s: LiveStatus) => void; onMessage?: (msg: any) => boolean }
) {
	let timer: ReturnType<typeof setTimeout> | undefined;
	const reload = () => {
		clearTimeout(timer);
		timer = setTimeout(load, 200);
	};
	load();
	const stop = subscribe('PublicChannel', { kind, token }, {
		onStatus: handlers.onStatus,
		onConnected: reload,
		// onMessage returns true when it applied the change itself
		onMessage: (msg) => handlers.onMessage?.(msg) || reload()
	});
	return () => {
		clearTimeout(timer);
		stop();
	};
}
