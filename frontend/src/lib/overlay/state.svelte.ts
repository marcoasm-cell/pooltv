import { roundLabel } from '../format.ts';
import { t } from '../i18n/index.svelte.ts';
import type { Match, OverlayConfig, PoolTable } from '../types.ts';

/** Ticks every second so time-based overlay states (winner banner) expire */
export function useClock() {
	let now = $state(Date.now());
	$effect(() => {
		const id = setInterval(() => (now = Date.now()), 1000);
		return () => clearInterval(id);
	});
	return {
		get now() {
			return now;
		}
	};
}

export type TableView = 'live' | 'winner' | 'waiting' | 'hidden';

/** What a table overlay shows right now */
export function tableView(table: PoolTable | null, config: OverlayConfig, now: number): TableView {
	if (!table || table.overlay.visible === false || table.overlay.visible === 'false') return 'hidden';
	const m = table.current_match;
	if (m?.status === 'live') return 'live';
	if (m?.status === 'finished' && m.finished_at) {
		const shownUntil = Date.parse(m.finished_at) + config.winner_banner_seconds * 1000;
		if (now < shownUntil) return 'winner';
	}
	return config.idle_mode === 'waiting' ? 'waiting' : 'hidden';
}

export function raceLabel(m: Match) {
	if (m.team_match && m.target === 1 && m.game_type.scoring_mode === 'racks') return t('common.singleGame');
	return m.game_type.scoring_mode === 'points' ? t('common.toPoints', { n: m.target }) : t('common.raceTo', { n: m.target });
}

/**
 * Caption of a match on the overlays: its name (or its tournament's), the round and the rubber.
 * A standalone team match is stored as a "friendly" tournament; that round name means nothing on air.
 */
export function matchCaption(m: Match, tableName?: string) {
	return [
		m.name ?? m.tournament?.name,
		m.round_label?.key === 'friendly' ? null : roundLabel(m.round_label),
		m.team_match && m.rubber_number ? t('overlay.rubber', { n: m.rubber_number }) : null,
		tableName
	]
		.filter(Boolean)
		.join(' · ');
}

/** What the team score counts towards, e.g. "race to 9" */
export function teamTargetLabel(tm: NonNullable<Match['team_match']>) {
	if (tm.win_condition === 'racks') return t('overlay.racks');
	return tm.target ? t('common.raceToLower', { n: tm.target }) : t('overlay.rubbers');
}

export function winnerName(m: Match) {
	return m.winner_side ? m[m.winner_side].name : '';
}
