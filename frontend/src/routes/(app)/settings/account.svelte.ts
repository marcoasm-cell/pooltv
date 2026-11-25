import { api } from '#lib/api.ts';
import { errorMessage } from '#lib/format.ts';
import type { Account, OverlayConfig } from '#lib/types.ts';

/** The club account with the overlay settings, shared by the overlay and branding pages */
export function accountSettings() {
	const s = $state({ account: null as Account | null, error: '', saved: false });
	let savedTimer: ReturnType<typeof setTimeout> | undefined;

	async function load() {
		s.account = await api<Account>('/account');
	}

	async function run(fn: () => Promise<unknown>) {
		s.error = '';
		try {
			await fn();
			await load();
			return true;
		} catch (e) {
			s.error = errorMessage(e);
			return false;
		}
	}

	async function saveOverlay(patch: Partial<OverlayConfig>) {
		if (!(await run(() => api('/account', { method: 'PATCH', body: { overlay_settings: patch } })))) return;
		s.saved = true;
		clearTimeout(savedTimer);
		savedTimer = setTimeout(() => (s.saved = false), 1200);
	}

	return { state: s, load, run, saveOverlay };
}
