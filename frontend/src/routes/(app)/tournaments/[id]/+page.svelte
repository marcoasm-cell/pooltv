<script lang="ts">
	import { goto } from '$app/navigation';
	import { SvelteSet } from 'svelte/reactivity';
	import { page } from '$app/state';
	import { api } from '#lib/api.ts';
	import FixtureCard from '#lib/components/FixtureCard.svelte';
	import { errorMessage, formatLabel, kindLabel, roundLabel } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { live } from '#lib/live.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { Entry, Fixture, Player, PoolTable, Team, Tournament } from '#lib/types.ts';
	import { downloadTournamentSheets, sheetFixtures } from '#lib/sheet/index.ts';

	const id = $derived(Number(page.params.id));
	let tour = $state<Tournament | null>(null);
	let tables = $state<PoolTable[]>([]);
	let players = $state<Player[]>([]);
	let teams = $state<Team[]>([]);
	let error = $state('');

	// One load at a time: a load asked for while one runs happens once after it
	let loading: Promise<void> | null = null;
	let again = false;
	function load(): Promise<void> {
		if (loading) {
			again = true;
			return loading;
		}
		loading = fetchTournament().finally(() => {
			loading = null;
			if (again) {
				again = false;
				load();
			}
		});
		return loading;
	}

	async function fetchTournament() {
		tour = await api<Tournament>(`/tournaments/${id}`);
		if (tour.kind === 'team') {
			// Rosters for the lineup pickers, fetched once rather than on every live update
			if (!teams.length) teams = await api<Team[]>('/teams');
			const rosters = new Map(teams.map((x) => [x.id, x.roster]));
			for (const e of tour.entries ?? []) if (e.team) e.team.roster = rosters.get(e.team.id);
			for (const f of tour.fixtures ?? [])
				for (const e of [f.home, f.away]) if (e?.team) e.team.roster = rosters.get(e.team.id);
		}
	}

	$effect(() => {
		load();
		api<PoolTable[]>('/pool_tables').then((x) => (tables = x));
		api<Player[]>('/players').then((x) => (players = x));
		let timer: ReturnType<typeof setTimeout>;
		return live.on((msg) => {
			const mine = (msg.type === 'fixture' && msg.fixture.tournament_id === id) || (msg.type === 'match' && msg.match.tournament?.id === id);
			if (!mine) return;
			// A result can touch many fixtures at once; reload once
			clearTimeout(timer);
			timer = setTimeout(load, 150);
		}, load);
	});

	async function run(fn: () => Promise<unknown>) {
		error = '';
		try {
			await fn();
			await load();
		} catch (e) {
			error = errorMessage(e);
		}
	}

	// Entries change only the list, so it is updated in place instead of
	// fetching the whole tournament again
	const bySeed = (a: Entry, b: Entry) => (a.seed ?? Infinity) - (b.seed ?? Infinity) || a.id - b.id;
	async function editEntries(fn: (entries: Entry[]) => Promise<void>) {
		error = '';
		try {
			await fn(tour!.entries!);
			tour!.entries!.sort(bySeed);
		} catch (e) {
			error = errorMessage(e);
		}
	}
	// Ids being added, so a double click does not send the same one twice
	const adding = new SvelteSet<number>();
	const addEntry = (value: number) => {
		if (adding.has(value)) return;
		adding.add(value);
		const body = tour!.kind === 'team' ? { team_id: value } : { player_id: value };
		return editEntries(async (entries) => {
			const entry = await api<Entry>(`/tournaments/${id}/entries`, { body });
			if (entry.team) entry.team.roster = teams.find((x) => x.id === entry.team!.id)?.roster;
			entries.push(entry);
		}).finally(() => adding.delete(value));
	};
	const seed = (entryId: number, value: string) =>
		editEntries(async (entries) => {
			const entry = await api<Entry>(`/tournaments/${id}/entries/${entryId}`, { method: 'PATCH', body: { seed: value || null } });
			const i = entries.findIndex((e) => e.id === entryId);
			if (i >= 0) entries[i] = { ...entries[i], seed: entry.seed };
		});
	const removeEntry = (entryId: number) =>
		editEntries(async (entries) => {
			await api(`/tournaments/${id}/entries/${entryId}`, { method: 'DELETE' });
			const i = entries.findIndex((e) => e.id === entryId);
			if (i >= 0) entries.splice(i, 1);
		});
	const start = () => run(() => api(`/tournaments/${id}/start`, { method: 'POST' }));
	const reset = () =>
		confirm(t('tournament.confirmReset')) && run(() => api(`/tournaments/${id}/reset`, { method: 'POST' }));
	const endEarly = () =>
		confirm(t('dashboard.confirmEndTournament', { name: tour!.name })) &&
		run(() => api(`/tournaments/${id}/end_early`, { method: 'POST' }));
	// Tables the games are dealt to; changing them gives a table to unassigned games
	const toggleTable = (tableId: number) => {
		const ids = tour!.pool_table_ids ?? [];
		const next = ids.includes(tableId) ? ids.filter((x) => x !== tableId) : [...ids, tableId];
		run(() => api(`/tournaments/${id}`, { method: 'PATCH', body: { pool_table_ids: next } }));
	};
	const archive = () => run(() => api(`/tournaments/${id}/archive`, { method: 'POST' }));
	const unarchive = () => run(() => api(`/tournaments/${id}/unarchive`, { method: 'POST' }));
	const remove = async () => {
		if (!confirm(t('tournament.confirmDelete'))) return;
		await api(`/tournaments/${id}`, { method: 'DELETE' });
		goto('/tournaments');
	};

	// Games of a team match, counted by kind: "16 × Individual", "4 × Individual, 1 × Pares"
	const teamFormat = $derived.by(() => {
		const counts = new Map<string, number>();
		for (const k of tour?.team_match_format ?? []) counts.set(k, (counts.get(k) ?? 0) + 1);
		return [...counts].map(([k, n]) => `${n} × ${kindLabel(k)}`).join(', ');
	});

	// Game sheets (PDF) of every fixture played so far
	const sheets = $derived(tour ? sheetFixtures(tour).length : 0);
	let sheetBusy = $state(false);
	async function downloadSheets() {
		sheetBusy = true;
		error = '';
		try {
			await downloadTournamentSheets(tour!);
		} catch (e) {
			error = errorMessage(e);
		} finally {
			sheetBusy = false;
		}
	}

	// Bracket columns: one per bracket + round
	const columns = $derived.by(() => {
		const order = ['winners', 'losers', 'grand_final', 'group'];
		const map = new Map<string, Fixture[]>();
		for (const f of tour?.fixtures ?? []) {
			const key = `${order.indexOf(f.bracket)}-${String(f.round).padStart(3, '0')}`;
			map.set(key, [...(map.get(key) ?? []), f]);
		}
		return [...map.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([, fs]) => fs);
	});
	const available = $derived.by(() => {
		const taken = new Set((tour?.entries ?? []).map((e) => (tour?.kind === 'team' ? e.team?.id : e.player?.id)));
		return (tour?.kind === 'team' ? teams : players).filter((x) => !taken.has(x.id) && !adding.has(x.id));
	});
	// Search box of the "add" list
	let query = $state('');
	const fold = (v: string) => v.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
	const matching = $derived(query.trim() ? available.filter((x) => fold(x.name).includes(fold(query.trim()))) : available);
	// Start needs 2 entries (exactly 2 for a friendly)
	const entryCount = $derived(tour?.entries?.length ?? 0);
	const canStart = $derived(tour?.format === 'friendly' ? entryCount === 2 : entryCount >= 2);
</script>

{#if tour}
	<header class="mb-8 flex flex-wrap items-end gap-3">
		<div class="flex-1">
			<a href="/tournaments" class="eyebrow mb-1 inline-block hover:underline">{t('tournament.back')}</a>
			<h1 class="page-title">{tour.name}</h1>
			<div class="mt-3 flex flex-wrap gap-1.5 text-xs">
				{#each [tour.game_type.name, tour.game_type.scoring_mode === 'points' ? t('tournament.toPoints', { n: tour.target }) : t('common.raceTo', { n: tour.target }), ...(tour.format === 'friendly' ? [] : [formatLabel(tour.format)]), ...(tour.kind === 'team' ? [t('tournament.teamsChip', { format: teamFormat })] : [])] as chip (chip)}
					<span class="rounded-full bg-white px-2.5 py-1 font-medium text-gray-600 ring-1 ring-gray-200">{chip}</span>
				{/each}
			</div>
		</div>
		{#if sheets}
			<button class="btn btn-ghost btn-sm" disabled={sheetBusy} onclick={downloadSheets}>
				<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11m0 0-4-4m4 4 4-4M5 19h14" /></svg>
				{sheetBusy ? t('score.sheetBusy') : sheets === 1 ? t('score.sheet') : t('tournament.sheets', { n: sheets })}
			</button>
		{/if}
		{#if session.canManage}
			{#if tour.status === 'draft'}
				<button class="btn btn-danger" onclick={remove}>{t('common.delete')}</button>
				<button class="btn btn-primary" disabled={!canStart} onclick={start}><span class="btn-icon">▶</span>{t('tournament.start')}</button>
			{:else}
				{#if tour.status === 'running'}<button class="btn btn-ghost btn-sm" onclick={endEarly}>{t('tournament.end')}</button>{/if}
				<button class="btn btn-danger btn-sm" onclick={reset}>{t('tournament.reset')}</button>
			{/if}
			{#if tour.archived_at}
				<button class="btn btn-ghost btn-sm" onclick={unarchive}>{t('tournament.unarchive')}</button>
			{:else if tour.status !== 'running'}
				<button class="btn btn-ghost btn-sm" onclick={archive}>{t('tournament.archive')}</button>
			{/if}
		{/if}
	</header>

	{#if tour.archived_at}
		<p class="mb-6 rounded-xl bg-gray-100 px-4 py-2.5 text-sm text-gray-600 ring-1 ring-gray-200">{t('tournament.archivedNote')}</p>
	{/if}
	{#if error}<p class="alert-error mb-4">{error}</p>{/if}
	{#if tour.status !== 'finished' && (session.canManage || tour.pool_table_ids?.length)}
		{@const active = tables.filter((x) => x.active || tour!.pool_table_ids?.includes(x.id))}
		<section class="mb-6 flex flex-wrap items-center gap-x-3 gap-y-2 rounded-2xl bg-white px-5 py-3 ring-1 ring-gray-200" title={t('tournament.tablesHint')}>
			<span class="eyebrow">{t('tournament.tables')}</span>
			<div class="flex flex-wrap gap-1.5">
				{#each active as x (x.id)}
					{@const on = tour.pool_table_ids?.includes(x.id)}
					{#if session.canManage}
						<button type="button" aria-pressed={on} onclick={() => toggleTable(x.id)}
							class="rounded-full border px-3 py-1 text-sm font-medium transition {on ? 'border-gold-400 bg-gold-100/50 text-gray-900' : 'border-gray-200 text-gray-500 hover:border-gray-300 hover:text-gray-800'}">
							{#if on}<span class="mr-1 text-gold-600">✓</span>{/if}{x.name}
						</button>
					{:else if on}
						<span class="rounded-full border border-gray-200 px-3 py-1 text-sm font-medium text-gray-700">{x.name}</span>
					{/if}
				{/each}
			</div>
		</section>
	{/if}
	{#if tour.ended_early}<p class="mb-4 text-sm text-gray-500">{t('tournament.endedEarly')}</p>{/if}

	{#if tour.winner}
		<div class="surface-dark mb-6 flex items-center gap-4 rounded-2xl px-6 py-5 text-white shadow-lg shadow-black/20">
			<span class="grid h-12 w-12 place-items-center rounded-full bg-gold-300 text-2xl">🏆</span>
			<div>
				<div class="text-xs font-bold tracking-widest text-gold-300 uppercase">{t('tournament.champion')}</div>
				<div class="font-display text-2xl font-extrabold">{tour.winner.name}</div>
			</div>
		</div>
	{/if}

	{#if tour.status === 'draft'}
		<section class="card grid overflow-hidden {session.canManage ? 'md:grid-cols-[3fr_2fr]' : ''}">
			<!-- Entrants, with an optional seed -->
			<div class="p-6">
				<div class="mb-4 flex items-center gap-2">
					<h2 class="text-lg">{tour.kind === 'team' ? t('tournament.teams') : t('tournament.players')}</h2>
					<span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-semibold text-gray-600 tabular-nums">{entryCount}</span>
				</div>
				<ul class="divide-y divide-gray-100">
					{#each tour.entries ?? [] as e (e.id)}
						<li class="group flex items-center gap-3 py-1.5">
							<input class="seed" type="number" min="1" placeholder="–" title={t('tournament.seedTitle')} aria-label={t('tournament.seedTitle')}
								value={e.seed ?? ''} disabled={!session.canManage} onchange={(ev) => seed(e.id, ev.currentTarget.value)} />
							<span class="min-w-0 flex-1 truncate font-medium">{e.name}</span>
							{#if session.canManage}
								<button class="grid h-7 w-7 place-items-center rounded-full text-gray-300 transition group-hover:text-gray-500 hover:bg-red-50 hover:text-red-600!"
									onclick={() => removeEntry(e.id)} aria-label={t('common.remove')} title={t('common.remove')}>×</button>
							{/if}
						</li>
					{:else}
						<li class="rounded-xl border-2 border-dashed border-gray-200 px-4 py-6 text-center text-sm text-gray-500">{t('tournament.noEntries')}</li>
					{/each}
				</ul>
			</div>

			<!-- Click to add -->
			{#if session.canManage}
				<div class="flex flex-col border-t border-gray-100 bg-gray-50 p-6 md:border-t-0 md:border-l">
					<input class="field mb-3" type="search" bind:value={query}
						placeholder={tour.kind === 'team' ? t('tournament.searchTeams') : t('tournament.searchPlayers')} />
					<div class="-mx-2 max-h-80 overflow-y-auto">
						{#each matching as x (x.id)}
							<button type="button" class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left text-sm text-gray-700 transition hover:bg-white hover:text-gray-950 hover:shadow-sm"
								onclick={() => addEntry(x.id)}>
								<span class="grid h-5 w-5 shrink-0 place-items-center rounded-full bg-white text-xs font-bold text-gold-600 ring-1 ring-gray-200">+</span>
								<span class="truncate">{x.name}</span>
							</button>
						{:else}
							<p class="px-2 py-4 text-center text-sm text-gray-400">{t('tournament.nothingToAdd')}</p>
						{/each}
					</div>
				</div>
			{/if}
		</section>
	{:else}
		{#if tour.standings}
			<section class="card mb-8 overflow-x-auto p-6">
				<h2 class="mb-3 text-lg">{t('tournament.standings')}</h2>
				<table class="data-table tabular-nums">
					<thead>
						<tr><th>#</th><th>{t('tournament.col.name')}</th><th>{t('tournament.col.played')}</th><th>{t('tournament.col.won')}</th><th>{t('tournament.col.drawn')}</th><th>{t('tournament.col.lost')}</th><th>+</th><th>−</th><th class="text-right">{t('tournament.col.points')}</th></tr>
					</thead>
					<tbody>
						{#each tour.standings as r, i (r.entry.id)}
							<tr>
								<td>
									<span class="grid h-6 w-6 place-items-center rounded-full text-xs font-bold {i === 0 ? 'bg-gold-300 text-gray-950' : 'text-gray-400'}">{i + 1}</span>
								</td>
								<td class="font-semibold">{r.entry.name}</td><td>{r.played}</td><td>{r.won}</td><td>{r.drawn}</td>
								<td>{r.lost}</td><td>{r.score_for}</td><td>{r.score_against}</td><td class="text-right font-display text-base font-extrabold">{r.points}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</section>
		{/if}

		<div class="-mx-4 flex gap-5 overflow-x-auto px-4 pb-4">
			{#each columns as fixtures (`${fixtures[0].bracket}-${fixtures[0].round}`)}
				<div class="flex w-72 flex-none flex-col gap-3">
					<h3 class="eyebrow border-b border-gray-200 pb-2">{roundLabel(fixtures[0].round_label)}</h3>
					<div class="flex flex-1 flex-col justify-around gap-3">
						{#each fixtures as f (f.id)}
							<FixtureCard fixture={f} tournament={tour} {tables} onchange={load} />
						{/each}
					</div>
				</div>
			{/each}
		</div>
	{/if}
{:else}
	<p class="text-gray-500">{t('common.loading')}</p>
{/if}

<style lang="postcss">
	@reference "../../../../app.css";

	.seed {
		@apply w-11 rounded-md border border-transparent bg-gray-100 py-1 text-center text-sm font-semibold text-gray-700 tabular-nums outline-none transition;
		appearance: textfield;
		-moz-appearance: textfield;
	}
	.seed:not(:disabled):hover {
		@apply border-gray-300;
	}
	.seed:focus {
		@apply border-gold-400 bg-white;
	}
	.seed::-webkit-inner-spin-button,
	.seed::-webkit-outer-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}
</style>
