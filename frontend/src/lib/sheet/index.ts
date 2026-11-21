// "Ficha de jogo": the game sheet of a match or team match, downloaded as a PDF
import { roundLabel } from '../format.ts';
import { i18n, t } from '../i18n/index.svelte.ts';
import type { Entry, Fixture, Match, Player, Side, Tournament } from '../types.ts';
import type { SheetModel, SheetPlayer, SheetRow } from './render.ts';

const names = (players: Player[]) => players.map((p) => p.display_name).join(' / ');

function dateOf(matches: Match[]) {
	const last = matches.map((m) => m.finished_at ?? m.started_at).filter(Boolean).sort().at(-1);
	return new Date(last ?? Date.now())
		.toLocaleString(i18n.locale, { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit' })
		.replace(',', '');
}

function subtitleOf(tournamentName: string | null | undefined, round: Fixture['round_label'] | null, gameType: string) {
	return [tournamentName, round && round.key !== 'friendly' ? roundLabel(round) : null, gameType].filter(Boolean).join(' · ');
}

/** Players of one team: the lineup in order (1, 2…), then whoever came in (S1, S2…) */
function roster(entry: Entry | null, side: Side, matches: Match[]): SheetPlayer[] {
	const played = matches.filter((m) => m.status === 'finished');
	const list = new Map<number, Player>();
	for (const s of entry?.lineup?.slots ?? []) list.set(s.starter.id, s.starter);
	const starters = list.size;
	for (const m of matches) for (const p of m[side].players) if (!list.has(p.id)) list.set(p.id, p);

	let subs = 0;
	return [...list.values()].map((p, i) => {
		const games = played.filter((m) => m[side].players.some((x) => x.id === p.id));
		const sub = starters > 0 && i >= starters;
		return {
			n: sub ? `S${++subs}` : String(i + 1),
			name: p.display_name,
			won: games.filter((m) => m.winner_side === side).length,
			lost: games.filter((m) => m.winner_side && m.winner_side !== side).length,
			sub
		};
	}).filter((p) => !p.sub || p.won + p.lost > 0);
}

/** Model of a team match: rosters and the games in blocks of one round each */
function teamModel(fixture: Fixture, opts: { tournamentName?: string | null; winCondition: 'rubbers' | 'racks' }): SheetModel {
	const matches = [...(fixture.matches ?? [])].sort((a, b) => (a.rubber_number ?? 0) - (b.rubber_number ?? 0));
	const homeSlots = fixture.home?.lineup?.slots ?? [];
	const awaySlots = fixture.away?.lineup?.slots ?? [];
	const size = homeSlots.length;
	const byNumber = new Map(matches.map((m) => [m.rubber_number ?? 0, m]));
	const total = Math.max(size * size, ...matches.map((m) => m.rubber_number ?? 0));

	let home = 0;
	let away = 0;
	const rows: SheetRow[] = [];
	for (let n = 1; n <= total; n++) {
		const m = byNumber.get(n);
		const i = (n - 1) % (size || total);
		if (m?.status === 'finished') {
			if (opts.winCondition === 'racks') {
				home += m.home.score;
				away += m.away.score;
			} else if (m.winner_side === 'home') home++;
			else if (m.winner_side === 'away') away++;
		}
		// A game dropped once the team match was decided: who would have played it
		const shift = Math.floor((n - 1) / (size || 1));
		const fallback = (slots: typeof homeSlots, k: number) => slots[k]?.current.display_name ?? '';
		rows.push({
			n: String(i + 1),
			home: m ? names(m.home.players) : size ? fallback(homeSlots, i) : '',
			away: m ? names(m.away.players) : size ? fallback(awaySlots, (i + shift) % size) : '',
			score: m?.status === 'finished' ? `${home} - ${away}` : '',
			winner: m?.status === 'finished' ? m.winner_side : null
		});
	}

	const chunk = size || rows.length || 1;
	const blocks = [];
	for (let i = 0; i < rows.length; i += chunk) {
		let block = rows.slice(i, i + chunk);
		// A round nobody played stays blank, like on paper
		if (!block.some((r) => r.score)) block = block.map((r) => ({ ...r, home: '', away: '' }));
		blocks.push({ title: t('sheet.block', { n: blocks.length + 1 }), rows: block });
	}

	const winner: Side | null = fixture.winner_entry_id
		? fixture.winner_entry_id === fixture.home?.id ? 'home' : 'away'
		: null;
	const team = (side: Side) => fixture[side]?.team;
	const nameOf = (side: Side) => team(side)?.name ?? fixture[side]?.name ?? '';
	return {
		title: t('sheet.title'),
		subtitle: subtitleOf(opts.tournamentName, fixture.round_label, matches[0]?.game_type.name ?? ''),
		date: dateOf(matches),
		home: { name: nameOf('home'), score: fixture.home_score },
		away: { name: nameOf('away'), score: fixture.away_score },
		winner,
		result: winner ? t('sheet.wins', { name: nameOf(winner) }) : fixture.status === 'finished' ? t('sheet.draw') : '',
		rosters: { home: roster(fixture.home, 'home', matches), away: roster(fixture.away, 'away', matches) },
		blocks,
		labels: { won: t('sheet.won'), lost: t('sheet.lost') }
	};
}

/** Model of a single match (player vs player, or doubles) */
function matchModel(m: Match): SheetModel {
	const w = m.winner_side;
	return {
		title: t('sheet.title'),
		subtitle: subtitleOf(m.name ?? m.tournament?.name, m.round_label, m.game_type.name),
		date: dateOf([m]),
		home: { name: m.home.name, score: m.home.score },
		away: { name: m.away.name, score: m.away.score },
		winner: w,
		result: w ? t('sheet.wins', { name: m[w].name }) : '',
		rosters: null,
		blocks: [{
			title: m.game_type.scoring_mode === 'points' ? t('sheet.toPoints', { n: m.target }) : t('sheet.raceTo', { n: m.target }),
			rows: [{ n: '1', home: names(m.home.players) || m.home.name, away: names(m.away.players) || m.away.name, score: `${m.home.score} - ${m.away.score}`, winner: m.status === 'finished' ? w : null }]
		}],
		labels: { won: t('sheet.won'), lost: t('sheet.lost') }
	};
}

const slug = (s: string) =>
	s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

/** The badge for the sheet header; the sheet still downloads if it cannot be fetched */
const loadLogo = () =>
	fetch('/logo.png')
		.then((r) => (r.ok ? r.arrayBuffer() : Promise.reject()))
		.then((b) => new Uint8Array(b))
		.catch(() => undefined);

async function download(models: SheetModel[], name: string) {
	const [{ jsPDF }, { renderSheets }, logo] = await Promise.all([import('jspdf'), import('./render.ts'), loadLogo()]);
	const title = `${t('sheet.title')} · ${name}`;
	renderSheets(models, jsPDF, title, logo).save(`${slug(t('sheet.title'))}-${slug(name)}.pdf`);
}

const pairName = (m: SheetModel) => `${m.home.name} - ${m.away.name}`;

/**
 * Downloads the sheet of a match: of its whole team match when it is a rubber
 * (the fixture is fetched by the caller), else of the match alone.
 */
export function downloadSheet(
	source:
		| { fixture: Fixture; tournamentName?: string | null; winCondition: 'rubbers' | 'racks'; team: true }
		| { match: Match; team?: false }
) {
	const model = source.team ? teamModel(source.fixture, source) : matchModel(source.match);
	return download([model], pairName(model));
}

/** Fixtures of a tournament with at least one game played: byes and walkovers have no sheet */
export const sheetFixtures = (tournament: Tournament) =>
	(tournament.fixtures ?? []).filter((f) => f.home && f.away && (f.matches ?? []).some((m) => m.status === 'finished'));

/** Every sheet of a tournament in one PDF, one page per fixture, in the order of play */
export function downloadTournamentSheets(tournament: Tournament) {
	const ref = { id: tournament.id, name: tournament.name, kind: tournament.kind, format: tournament.format };
	const models = sheetFixtures(tournament)
		.map((f) => ({ f, at: f.matches!.map((m) => m.started_at ?? '').filter(Boolean).sort()[0] ?? '' }))
		.sort((a, b) => a.at.localeCompare(b.at) || a.f.round - b.f.round || a.f.position - b.f.position)
		.map(({ f }) =>
			tournament.kind === 'team'
				? teamModel(f, { tournamentName: tournament.name, winCondition: tournament.team_win_condition })
				: matchModel({ ...f.matches![0], tournament: ref, round_label: f.round_label })
		);
	return download(models, models.length === 1 ? pairName(models[0]) : tournament.name);
}
