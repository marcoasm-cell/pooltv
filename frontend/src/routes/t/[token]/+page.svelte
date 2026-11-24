<!--
  Public page of a tournament, reached by its QR code: the tree (elimination) or the standings
  and the drawn fixtures (round robin), with the matches on now. Live, no sign-in.
-->
<script lang="ts">
	import { page } from '$app/state';
	import { api } from '#lib/api.ts';
	import type { LiveStatus } from '#lib/cable.ts';
	import { formatLabel, kindLabel, roundLabel } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import Bracket from '#lib/public/Bracket.svelte';
	import { follow } from '#lib/public/follow.ts';
	import MatchRow from '#lib/public/MatchRow.svelte';
	import Shell from '#lib/public/Shell.svelte';
	import type { Branding, Fixture, Match, PublicTable, Tournament } from '#lib/types.ts';

	const token = $derived(page.params.token!);
	let tour = $state<Tournament | null>(null);
	let branding = $state<Branding | null>(null);
	let tables = $state<PublicTable[]>([]);
	let error = $state('');
	let status = $state<LiveStatus>('connecting');

	async function load() {
		try {
			const data = await api<{ tournament: Tournament; branding: Branding; tables: PublicTable[] }>(`/public/tournaments/${token}`, { auth: false });
			({ tournament: tour, branding, tables } = data);
			error = '';
		} catch (e) {
			error = (e as Error).message;
		}
	}

	// Every change reloads the tournament: a result moves scores, standings and the next round at once
	$effect(() => follow('tournament', token, load, { onStatus: (s) => (status = s) }));

	const fixtures = $derived(tour?.fixtures ?? []);
	const team = $derived(tour?.kind === 'team');
	const elimination = $derived(tour?.format === 'single_elimination' || tour?.format === 'double_elimination');
	const brackets = $derived(
		(['winners', 'losers', 'grand_final'] as const)
			.map((key) => ({ key, fixtures: fixtures.filter((f) => f.bracket === key) }))
			.filter((b) => b.fixtures.length)
	);
	// Round robin: the drawn fixtures, round by round
	const rounds = $derived.by(() => {
		const map = new Map<number, Fixture[]>();
		for (const f of fixtures.filter((x) => x.bracket === 'group')) map.set(f.round, [...(map.get(f.round) ?? []), f]);
		return [...map.entries()].sort(([a], [b]) => a - b).map(([r, fs]) => [r, fs.sort((a, b) => a.position - b.position)] as const);
	});

	// Each match with where it belongs, to caption it in the lists
	const matches = $derived(fixtures.flatMap((f) => (f.matches ?? []).map((m) => ({ m, f }))));
	const caption = (m: Match, f: Fixture) =>
		[
			tour?.format === 'friendly' ? null : roundLabel(f.round_label),
			team && m.rubber_number ? t('fixture.rubber', { n: m.rubber_number, kind: kindLabel(m.kind) }) : null
		]
			.filter(Boolean)
			.join(' · ');
	const liveNow = $derived(matches.filter(({ m }) => m.status === 'live'));
	// Next games already set on a table, in the order they will be played there
	const nextUp = $derived(
		matches
			.filter(({ m, f }) => m.status === 'scheduled' && m.pool_table_id && f.home && f.away && (m.home.players.length || !team))
			.sort((a, b) => (a.m.queue_position ?? 0) - (b.m.queue_position ?? 0) || a.m.id - b.m.id)
			.slice(0, 6)
	);
	const friendly = $derived(tour?.format === 'friendly' ? fixtures[0] : null);
	const chips = $derived(
		tour
			? [
					tour.game_type.name,
					tour.game_type.scoring_mode === 'points' ? t('common.toPoints', { n: tour.target }) : team && tour.target === 1 ? t('common.singleGame') : t('common.raceTo', { n: tour.target }),
					tour.format === 'friendly' ? (team ? t('public.teamMatch') : null) : formatLabel(tour.format)
				].filter((x): x is string => !!x)
			: []
	);
</script>

<svelte:head><title>{tour ? t('public.title', { name: tour.name }) : 'Pool TV'}</title></svelte:head>

{#snippet fixtureLine(f: Fixture)}
	{@const single = !team && f.matches?.length === 1 ? f.matches[0] : null}
	{@const started = f.status === 'live' || f.status === 'finished'}
	<svelte:element this={single ? 'a' : 'div'} href={single ? `/m/${single.public_token}` : undefined}
		class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-3 px-4 py-2.5 text-sm {single ? 'transition hover:bg-gray-50' : ''}"
		class:opacity-50={f.status === 'void'}>
		{#each [['home', f.home, f.home_bye], ['away', f.away, f.away_bye]] as const as [side, entry, bye], i (side)}
			{#if i === 1}
				{#if started}
					<span class="flex items-center gap-1.5">
						{#if f.status === 'live'}<span class="h-1.5 w-1.5 animate-pulse rounded-full bg-red-500"></span>{/if}
						<span class="rounded-md bg-gray-950 px-2 py-0.5 font-display font-extrabold text-white tabular-nums">{f.home_score}–{f.away_score}</span>
					</span>
				{:else}
					<span class="px-2 text-xs font-bold text-gray-400 uppercase">{t('common.vs')}</span>
				{/if}
			{/if}
			{@const won = !!entry && entry.id === f.winner_entry_id}
			<span class="truncate {side === 'home' ? 'text-right' : ''} {won ? 'font-bold text-gray-950' : f.winner_entry_id ? 'text-gray-400' : 'font-medium'}">
				{entry?.display_name ?? (bye ? t('fixture.bye') : t('fixture.tbd'))}
			</span>
		{/each}
	</svelte:element>
{/snippet}

{#snippet matchList(title: string, items: { m: Match; f: Fixture }[])}
	<section class="mb-8">
		<h2 class="eyebrow mb-3">{title}</h2>
		<div class="card divide-y divide-gray-100 overflow-hidden">
			{#each items as { m, f } (m.id)}
				<MatchRow match={m} {tables} caption={caption(m, f)} />
			{/each}
		</div>
	</section>
{/snippet}

<Shell {branding} {status}>
	{#if error && !tour}
		<p class="card p-6 text-center text-gray-600">{t('public.notFound')}</p>
	{:else if tour}
		<header class="mb-6">
			<p class="eyebrow mb-1">{t(`public.status.${tour.status}`)}</p>
			<h1 class="page-title">{tour.name}</h1>
			<div class="mt-3 flex flex-wrap gap-1.5 text-xs">
				{#each chips as chip (chip)}
					<span class="rounded-full bg-white px-2.5 py-1 font-medium text-gray-600 ring-1 ring-gray-200">{chip}</span>
				{/each}
			</div>
		</header>

		{#if tour.ended_early}<p class="mb-4 text-sm text-gray-500">{t('tournament.endedEarly')}</p>{/if}

		{#if tour.winner}
			<div class="surface-dark mb-8 flex items-center gap-4 rounded-2xl px-6 py-5 text-white">
				<span class="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-white/10 text-2xl">🏆</span>
				<div class="min-w-0">
					<div class="text-xs font-bold tracking-widest text-gold-300 uppercase">{t('tournament.champion')}</div>
					<div class="truncate font-display text-2xl font-extrabold">{tour.winner.name}</div>
				</div>
			</div>
		{/if}

		{#if tour.status === 'draft'}
			<section class="card p-6">
				<h2 class="mb-1 text-lg">{team ? t('tournament.teams') : t('tournament.players')}</h2>
				<p class="mb-4 text-sm text-gray-500">{t('public.draw')}</p>
				<ul class="grid gap-x-6 gap-y-1.5 sm:grid-cols-2">
					{#each tour.entries ?? [] as e (e.id)}<li class="truncate font-medium">{e.name}</li>{/each}
				</ul>
			</section>
		{:else}
			{#if liveNow.length}{@render matchList(t('public.liveNow'), liveNow)}{/if}

			{#if friendly}
				<!-- A single match or team match -->
				{#if team}
					<section class="mb-8">
						<h2 class="eyebrow mb-3">{t('public.games')}</h2>
						<div class="card divide-y divide-gray-100 overflow-hidden">
							{@render fixtureLine(friendly)}
							{#each friendly.matches ?? [] as m (m.id)}
								<MatchRow match={m} {tables} caption={caption(m, friendly)} />
							{/each}
						</div>
					</section>
				{:else}
					<div class="card overflow-hidden">{@render fixtureLine(friendly)}</div>
				{/if}
			{:else if elimination}
				{#each brackets as b (b.key)}
					<section class="mb-8">
						{#if brackets.length > 1}
							<h2 class="mb-3 text-lg">{t(b.key === 'winners' ? 'public.winnersBracket' : b.key === 'losers' ? 'public.losersBracket' : 'public.grandFinal')}</h2>
						{/if}
						<Bracket fixtures={b.fixtures} />
					</section>
				{/each}
				{#if nextUp.length}{@render matchList(t('public.nextUp'), nextUp)}{/if}
			{:else}
				{#if tour.standings}
					<section class="card mb-8 overflow-x-auto p-5">
						<h2 class="mb-3 text-lg">{t('tournament.standings')}</h2>
						<table class="data-table tabular-nums">
							<thead>
								<tr><th>#</th><th>{t('tournament.col.name')}</th><th>{t('tournament.col.played')}</th><th>{t('tournament.col.won')}</th>
									{#if tour.format === 'round_robin'}<th>{t('tournament.col.drawn')}</th>{/if}
									<th>{t('tournament.col.lost')}</th><th>+</th><th>−</th><th class="text-right">{t('tournament.col.points')}</th></tr>
							</thead>
							<tbody>
								{#each tour.standings as r, i (r.entry.id)}
									<tr>
										<td><span class="grid h-6 w-6 place-items-center rounded-full text-xs font-bold {i === 0 && r.played ? 'bg-gold-300 text-gray-950' : 'text-gray-400'}">{i + 1}</span></td>
										<td class="max-w-48 truncate font-semibold">{r.entry.name}</td><td>{r.played}</td><td>{r.won}</td>
										{#if tour.format === 'round_robin'}<td>{r.drawn}</td>{/if}
										<td>{r.lost}</td><td>{r.score_for}</td><td>{r.score_against}</td>
										<td class="text-right font-display text-base font-extrabold">{r.points}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</section>
				{/if}

				{#if nextUp.length}{@render matchList(t('public.nextUp'), nextUp)}{/if}

				<section>
					<h2 class="eyebrow mb-3">{t('public.fixtures')}</h2>
					<div class="grid gap-4 md:grid-cols-2">
						{#each rounds as [round, fs] (round)}
							<div class="card overflow-hidden">
								<h3 class="border-b border-gray-100 bg-gray-50 px-4 py-2 font-condensed text-sm font-bold tracking-[0.12em] text-gray-600 uppercase">
									{roundLabel(fs[0].round_label)}
								</h3>
								<div class="divide-y divide-gray-100">
									{#each fs as f (f.id)}{@render fixtureLine(f)}{/each}
								</div>
							</div>
						{/each}
					</div>
				</section>
			{/if}
		{/if}
	{:else}
		<p class="text-gray-500">{t('common.loading')}</p>
	{/if}
</Shell>
