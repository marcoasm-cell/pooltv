import { createConsumer, type Consumer } from '@rails/actioncable';
import { API_URL } from './api.ts';

const CABLE_URL: string =
	import.meta.env.VITE_CABLE_URL ?? API_URL.replace(/^http/, 'ws') + '/cable';

export type LiveStatus = 'connecting' | 'connected' | 'disconnected';

/**
 * Subscribes to a channel and hands every message to `onMessage`.
 * `onStatus` reports the connection so the UI can block input while offline;
 * `onConnected` runs on every (re)connect, so callers reload their snapshot
 * and never miss changes made while disconnected.
 */
export function subscribe(
	channel: 'OverlayChannel' | 'AccountChannel' | 'PublicChannel',
	params: Record<string, string>,
	handlers: {
		onMessage: (data: any) => void;
		onConnected?: () => void;
		onStatus?: (status: LiveStatus) => void;
		sessionToken?: string | null;
	}
): () => void {
	const url = handlers.sessionToken
		? `${CABLE_URL}?token=${encodeURIComponent(handlers.sessionToken)}`
		: CABLE_URL;
	const consumer: Consumer = createConsumer(url);
	handlers.onStatus?.('connecting');

	consumer.subscriptions.create(
		{ channel, ...params },
		{
			connected() {
				handlers.onStatus?.('connected');
				handlers.onConnected?.();
			},
			disconnected() {
				handlers.onStatus?.('disconnected');
			},
			rejected() {
				handlers.onStatus?.('disconnected');
			},
			received(data: unknown) {
				handlers.onMessage(data);
			}
		}
	);

	return () => consumer.disconnect();
}
