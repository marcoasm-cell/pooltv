import { subscribe, type LiveStatus } from './cable.ts';
import { session } from './session.svelte.ts';

type Listener = (msg: any) => void;

/**
 * One AccountChannel connection shared by every signed-in page. Pages
 * register listeners with `onLive`; `connected` drives the offline banner
 * and blocks scoring while the server cannot be reached.
 */
class Live {
	status = $state<LiveStatus>('connecting');
	#listeners = new Set<Listener>();
	#reconnectListeners = new Set<() => void>();
	#stop: (() => void) | null = null;

	get connected() {
		return this.status === 'connected';
	}

	start() {
		this.stop();
		this.#stop = subscribe('AccountChannel', {}, {
			sessionToken: session.token,
			onStatus: (s) => (this.status = s),
			onConnected: () => this.#reconnectListeners.forEach((fn) => fn()),
			onMessage: (msg) => this.#listeners.forEach((fn) => fn(msg))
		});
	}

	stop() {
		this.#stop?.();
		this.#stop = null;
	}

	/** Use inside $effect: returns the unsubscribe function */
	on(listener: Listener, onReconnect?: () => void) {
		this.#listeners.add(listener);
		if (onReconnect) this.#reconnectListeners.add(onReconnect);
		return () => {
			this.#listeners.delete(listener);
			if (onReconnect) this.#reconnectListeners.delete(onReconnect);
		};
	}
}

export const live = new Live();
