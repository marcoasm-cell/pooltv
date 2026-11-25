import { redirect } from '@sveltejs/kit';

// Each settings section is its own page; the first one is the default
export function load() {
	redirect(307, '/settings/overlays');
}
