import type { Match } from '../types.ts';

/**
 * Address of the public pages, as put in the QR codes: VITE_PUBLIC_URL, else this site.
 * The Android app is not on the web (capacitor://), so it needs VITE_PUBLIC_URL.
 */
function base() {
	const configured: string | undefined = import.meta.env.VITE_PUBLIC_URL;
	if (configured) return configured.replace(/\/$/, '');
	return /^https?:$/.test(location.protocol) ? location.origin : 'https://pooltv.me';
}

export const matchPageUrl = (token: string) => `${base()}/m/${token}`;
export const tournamentPageUrl = (token: string) => `${base()}/t/${token}`;

/** Where a QR code for a match sends people: its tournament (bracket or table), else the match */
export function publicUrl(m: Pick<Match, 'public_token' | 'tournament'>) {
	return m.tournament?.public_token ? tournamentPageUrl(m.tournament.public_token) : matchPageUrl(m.public_token);
}
