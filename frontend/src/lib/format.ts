import { t, tk } from './i18n/index.svelte.ts';
import type { RoundName, Tournament } from './types.ts';

export const FORMATS: Tournament['format'][] = ['single_elimination', 'double_elimination', 'round_robin', 'friendly'];

export const formatLabel = (format: string) => tk(`format.${format}`);

/** Name of a round sent by the server as { key, round } */
export function roundLabel(name: RoundName | null | undefined) {
	return name ? tk(`round.${name.key}`, { n: name.round }) : '';
}

export const kindLabel = (kind: string) => tk(`kind.${kind}`);

export function errorMessage(e: unknown) {
	return e instanceof Error ? e.message : String(e);
}

/** Full URL of an overlay page, as pasted into OBS */
export function overlayUrl(path: string) {
	return `${location.origin}${path}`;
}
