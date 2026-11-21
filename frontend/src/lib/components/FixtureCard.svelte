<!-- A fixture in the bracket: entries, score and, while it is on, its matches -->
<script lang="ts">
	import { api } from '../api.ts';
	import { errorMessage, kindLabel } from '../format.ts';
	import { t } from '../i18n/index.svelte.ts';
	import { session } from '../session.svelte.ts';
	import type { Entry, Fixture, Match, PoolTable, Tournament } from '../types.ts';
	import { downloadSheet } from '../sheet/index.ts';

	let { fixture, tournament, tables, onchange }: {
		fixture: Fixture;
		tournament: Tournament;
		tables: PoolTable[];
		onchange: () => void;
	} = $props();

	let error = $state('');
	const open = $derived(fixture.status === 'ready' || fixture.status === 'live');
	const team = $derived(tournament.kind === 'team');

	async function run(fn: () => Promise<unknown>) {
		error = '';
		try {
			await fn();
			onchange();
		} catch (e) {
			error = errorMessage(e);
		}
	}

	const assign = (m: Match, tableId: string) =>
		run(() => api(`/matches/${m.id}/assign`, { body: { pool_table_id: tableId || null } }));
	const lineup = (m: Match, side: 'home' | 'away', index: number, playerId: string) => {
		const ids = { home: m.home.players.map((p) => p.id), away: m.away.players.map((p) => p.id) };
		ids[side][index] = Number(playerId);
		ids[side] = ids[side].filter(Boolean);
		return run(() => api(`/matches/${m.id}/lineup`, { method: 'PUT', body: ids }));
	};
	const walkover = (side: 'home' | 'away') =>
		confirm(t('fixture.confirmWalkover', { name: fixture[side]?.display_name ?? '' })) &&
		run(() => api(`/fixtures/${fixture.id}/walkover`, { body: { winner_side: side } }));
	// Standalone team matches change players through substitutions only
	const hasLineup = $derived(!!fixture.home?.lineup);
	const substitute = (side: 'home' | 'away', slot: number, playerId: string) =>
		playerId && run(() => api(`/fixtures/${fixture.id}/substitute`, { body: { side, slot, player_id: Number(playerId) } }));
	const decider = () => run(() => api(`/fixtures/${fixture.id}/add_rubber`, { body: { kind: 'singles' } }));

	function slotName(entry: Entry | null, bye: boolean) {
		return entry?.display_name ?? (bye ? t('fixture.bye') : t('fixture.tbd'));
	}
	const sheet = () =>
		run(async () => {
			const f = fixture.matches ? fixture : await api<Fixture>(`/fixtures/${fixture.id}`);
			if (team) await downloadSheet({ team: true, fixture: f, tournamentName: tournament.name, winCondition: tournament.team_win_condition });
			else if (f.matches?.[0]) await downloadSheet({ match: { ...f.matches[0], tournament: { id: tournament.id, name: tournament.name, kind: tournament.kind, format: tournament.format }, round_label: f.round_label } });
		});
	const tied = $derived(team && fixture.status === 'live' && (fixture.matches ?? []).every((m) => m.status === 'finished') && fixture.home_score === fixture.away_score);
</script>

<div class="card overflow-hidden text-sm" class:opacity-50={fixture.status === 'void'} class:live={fixture.status === 'live'}>
	{#each [['home', fixture.home, fixture.home_bye, fixture.home_score], ['away', fixture.away, fixture.away_bye, fixture.away_score]] as const as [side, entry, bye, score] (side)}
		<div class="flex items-center gap-2 px-3 py-2 {side === 'away' ? 'border-t border-gray-100' : ''}" class:winner={entry && entry.id === fixture.winner_entry_id}>
			<span class="flex-1 truncate" class:text-gray-400={!entry}>{slotName(entry, bye)}</span>
			{#if fixture.status !== 'pending' && fixture.status !== 'void'}<span class="score grid h-6 min-w-6 place-items-center rounded-md bg-gray-100 px-1.5 font-display font-extrabold tabular-nums">{score}</span>{/if}
			{#if open && session.canManage}
				<button class="rounded px-1 text-[10px] font-semibold text-gray-400 hover:bg-red-50 hover:text-red-600" title={t('fixture.walkoverTitle')} onclick={() => walkover(side)}>{t('fixture.walkover')}</button>
			{/if}
		</div>
	{/each}

	{#if open && hasLineup}
		<div class="grid grid-cols-2 gap-3 border-t border-gray-100 p-3">
			{#each ['home', 'away'] as const as side (side)}
				{@const lineup = fixture[side]?.lineup}
				<div>
					<div class="eyebrow mb-1.5 truncate text-[10px]!">{t('fixture.lineup', { name: fixture[side]?.display_name ?? '' })}</div>
					{#each lineup?.slots ?? [] as slot, i (i)}
						{@const options = (lineup?.bench ?? []).filter((p) => p.reserve || p.starter_slot === i)}
						<div class="mb-1 flex items-center gap-1 text-xs">
							<span class="w-5 font-bold text-gray-400 tabular-nums">{i + 1}º</span>
							<span class="flex-1 truncate" title={slot.current.id !== slot.starter.id ? t('fixture.replacing', { name: slot.starter.display_name }) : ''}>
								{slot.current.display_name}
								{#if slot.current.id !== slot.starter.id}<span class="text-gold-600">⇄ {slot.starter.display_name}</span>{/if}
							</span>
							{#if options.length}
								<select class="w-16 rounded-md border border-gray-200 bg-white px-0.5 py-0.5 text-[11px]" value="" onchange={(e) => substitute(side, i, e.currentTarget.value)} title={t('fixture.substitute')}>
									<option value="">{t('fixture.sub')}</option>
									{#each options as p (p.id)}<option value={p.id}>{p.display_name}</option>{/each}
								</select>
							{/if}
						</div>
					{/each}
					{#if lineup?.bench.length}
						<div class="mt-1 text-[11px] text-gray-500">{t('fixture.bench', { list: lineup.bench.map((p) => p.display_name + (p.reserve ? '' : t('fixture.onlyPosition', { n: (p.starter_slot ?? 0) + 1 }))).join(', ') })}</div>
					{/if}
				</div>
			{/each}
		</div>
	{/if}

	{#if open}
		<div class="space-y-2 border-t border-gray-100 bg-gray-50 p-2.5">
			{#each fixture.matches ?? [] as m (m.id)}
				<div class="rounded-lg bg-white p-2 ring-1 ring-gray-200">
					{#if team}
						<div class="eyebrow mb-1 text-[10px]! text-gray-500!">{t('fixture.rubber', { n: m.rubber_number ?? '', kind: kindLabel(m.kind) })}</div>
					{/if}
					{#if team && m.status === 'scheduled' && !hasLineup}
						<div class="mb-1 grid grid-cols-2 gap-1">
							{#each ['home', 'away'] as const as side (side)}
								<div class="space-y-1">
									{#each Array(m.kind === 'doubles' ? 2 : 1) as _, i (i)}
										<select class="w-full rounded-md border border-gray-200 bg-white px-1 py-0.5 text-xs" value={m[side].players[i]?.id ?? ''}
											onchange={(e) => lineup(m, side, i, e.currentTarget.value)}>
											<option value="">{t('fixture.pickPlayer')}</option>
											{#each fixture[side]?.team?.roster ?? [] as p (p.id)}<option value={p.id}>{p.display_name}</option>{/each}
										</select>
									{/each}
								</div>
							{/each}
						</div>
					{:else}
						<div class="text-xs">
							{m.home.name} <b class="mx-0.5 rounded bg-gray-950 px-1.5 py-0.5 font-display text-white tabular-nums">{m.home.score}–{m.away.score}</b> {m.away.name}
							{#if m.status === 'live'}<span class="badge badge-live ml-1 px-1.5! py-0! text-[9px]!">{t('common.live')}</span>{/if}
							{#if m.status === 'finished'}<span class="ml-1 text-[10px] font-semibold tracking-wider text-gray-400 uppercase">{t('common.final')}</span>{/if}
						</div>
					{/if}
					{#if m.status === 'scheduled' && session.canManage}
						<select class="mt-1.5 w-full rounded-md border border-gray-200 bg-white px-1 py-0.5 text-xs" value={m.pool_table_id ?? ''} onchange={(e) => assign(m, e.currentTarget.value)}>
							<option value="">{t('fixture.noTable')}</option>
							{#each tables as t (t.id)}<option value={t.id}>{t.name}</option>{/each}
						</select>
					{:else if m.status === 'live' && m.pool_table_id}
						<a class="mt-1 inline-block text-xs font-semibold text-gray-900 underline decoration-gold-400 underline-offset-2 hover:text-gold-600" href="/score/{m.pool_table_id}">
							{t('fixture.scoreOn', { table: tables.find((x) => x.id === m.pool_table_id)?.name ?? '' })}
						</a>
					{/if}
				</div>
			{/each}
			{#if tied && session.canManage}
				<button class="btn btn-gold btn-sm w-full" onclick={decider}>{t('fixture.decider')}</button>
			{/if}
		</div>
	{/if}
	{#if fixture.status === 'finished' && !fixture.home_bye && !fixture.away_bye && (fixture.matches?.length ?? 1)}
		<button class="w-full border-t border-gray-100 px-3 py-1.5 text-left text-xs font-semibold text-gray-500 hover:bg-gray-50 hover:text-gold-600" onclick={sheet}>↓ {t('score.sheet')}</button>
	{/if}
	{#if error}<p class="px-3 pb-2 text-xs text-red-600">{error}</p>{/if}
</div>

<style>
	.live {
		border-color: var(--color-red-300);
		box-shadow: 0 0 0 3px rgb(192 57 43 / 0.12);
	}
	.winner {
		font-weight: 700;
		color: var(--color-gray-950);
	}
	.winner .score {
		background: #000;
		color: var(--color-gold-300);
	}
</style>
