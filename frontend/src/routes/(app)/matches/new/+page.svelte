<!--
  A match outside any tournament, straight onto a table: players against
  players (singles/doubles), or a 4 v 4 team match: each team lists its
  players in order, the first 4 play and the rest are replacements, and every
  player meets every opposing player once.
-->
<script lang="ts">
	import { goto } from '$app/navigation';
	import { api } from '#lib/api.ts';
	import { errorMessage } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import type { GameType, Player, PoolTable, Side, Team } from '#lib/types.ts';

	type Kind = 'singles' | 'doubles' | 'team';
	const SIDES = ['home', 'away'] as const;
	const TEAM_SIZE = 4;
	const MAX_RESERVES = 2;
	const MAX_PICKED = TEAM_SIZE + MAX_RESERVES;

	let gameTypes = $state<GameType[]>([]);
	let players = $state<Player[]>([]);
	let teams = $state<Team[]>([]);
	let tables = $state<PoolTable[]>([]);
	let error = $state('');
	let saving = $state(false);
	let form = $state({ game_type_id: 0, target: 5, kind: 'singles' as Kind, pool_table_id: 0, name: '' });

	// Players mode: chosen player ids per slot
	let lineup = $state<Record<Side, number[]>>({ home: [0, 0], away: [0, 0] });
	// Team mode: chosen team and its players in order; the first TEAM_SIZE
	// play, the rest are replacements
	let teamId = $state<Record<Side, number>>({ home: 0, away: 0 });
	let picked = $state<Record<Side, number[]>>({ home: [], away: [] });
	const starters = (side: Side) => picked[side].slice(0, TEAM_SIZE);
	const reservesOf = (side: Side) => picked[side].slice(TEAM_SIZE);
	// Inline "new" inputs; null when closed
	let newPlayer = $state<Record<string, string | null>>({});
	let newTeam = $state<Record<Side, string | null>>({ home: null, away: null });
	// Team mode: tables in the order games are dealt to them
	let teamTables = $state<number[]>([]);

	function toggleTable(id: number) {
		const i = teamTables.indexOf(id);
		if (i >= 0) teamTables.splice(i, 1);
		else teamTables.push(id);
	}

	// Which table of a team match a game goes to
	const tableOf = (game: number) => tables.find((x) => x.id === teamTables[game % teamTables.length])?.name;

	const perSide = $derived(form.kind === 'doubles' ? 2 : 1);
	const playerById = $derived(new Map(players.map((p) => [p.id, p])));
	const teamById = $derived(new Map(teams.map((x) => [x.id, x])));
	// Team match: first team to this many games wins
	let raceTo = $state(9);
	const teamsReady = $derived(picked.home.length >= TEAM_SIZE && picked.away.length >= TEAM_SIZE);
	// 1v1, 2v2, 3v3, 4v4, then 1v2, 2v3, 3v4, 4v1, and so on
	const pairings = Array.from({ length: TEAM_SIZE }, (_, shift) =>
		Array.from({ length: TEAM_SIZE }, (_, i) => [i, (i + shift) % TEAM_SIZE])
	).flat();

	$effect(() => {
		api<GameType[]>('/game_types').then((g) => {
			gameTypes = g;
			pickGame((g.find((x) => x.key === 'pt_pool') ?? g[0]).id);
		});
		loadPlayers();
		loadTeams();
		api<PoolTable[]>('/pool_tables').then((x) => {
			tables = x.filter((tb) => tb.active);
			form.pool_table_id = tables.find((x) => !x.current_match || x.current_match.status !== 'live')?.id ?? tables[0]?.id ?? 0;
			if (form.pool_table_id) teamTables = [form.pool_table_id];
		});
	});

	const loadPlayers = async () => (players = await api<Player[]>('/players'));
	const loadTeams = async () => (teams = await api<Team[]>('/teams'));

	function pickGame(id: number) {
		form.game_type_id = id;
		form.target = gameTypes.find((g) => g.id === id)?.default_target ?? form.target;
	}

	async function run(fn: () => Promise<void>) {
		error = '';
		try {
			await fn();
		} catch (err) {
			error = errorMessage(err);
		}
	}

	// ---- Players mode ----

	function addPlayerToSlot(side: Side, i: number) {
		const key = `${side}-${i}`;
		const name = newPlayer[key]?.trim();
		if (!name) return;
		run(async () => {
			const p = await api<Player>('/players', { body: { name } });
			await loadPlayers();
			lineup[side][i] = p.id;
			newPlayer[key] = null;
		});
	}

	// ---- Team mode ----

	function pickTeam(side: Side, id: number) {
		teamId[side] = id;
		const roster = teamById.get(id)?.roster ?? [];
		picked[side] = roster.slice(0, MAX_PICKED).map((p) => p.id);
	}

	function createTeam(side: Side) {
		const name = newTeam[side]?.trim();
		if (!name) return;
		run(async () => {
			const x = await api<Team>('/teams', { body: { name } });
			await loadTeams();
			pickTeam(side, x.id);
			newTeam[side] = null;
		});
	}

	function addPlayerToTeam(side: Side) {
		const name = newPlayer[side]?.trim();
		const team = teamById.get(teamId[side]);
		if (!name || !team) return;
		run(async () => {
			const p = await api<Player>('/players', { body: { name } });
			const roster = [...(team.roster ?? []).map((r) => ({ player_id: r.id, captain: r.captain })), { player_id: p.id, captain: false }];
			await api(`/teams/${team.id}/roster`, { method: 'PUT', body: { roster } });
			await Promise.all([loadPlayers(), loadTeams()]);
			if (picked[side].length < MAX_PICKED) picked[side].push(p.id);
			newPlayer[side] = null;
		});
	}

	function move(side: Side, i: number, delta: number) {
		const list = picked[side];
		const j = i + delta;
		if (j < 0 || j >= list.length) return;
		[list[i], list[j]] = [list[j], list[i]];
	}

	const bench = (side: Side) =>
		(teamById.get(teamId[side])?.roster ?? []).filter((p) => !picked[side].includes(p.id));
	const nameOf = (id: number) => playerById.get(id)?.display_name ?? '?';
	const initials = (name: string) =>
		name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
	const SIDE_COLOR: Record<Side, string> = { home: '#1e5aa8', away: '#c0392b' };
	const sideColor = (side: Side) => SIDE_COLOR[side];
	const gameType = $derived(gameTypes.find((g) => g.id === form.game_type_id));
	const KINDS = $derived<{ value: Kind; label: string; hint: string }[]>([
		{ value: 'singles', label: t('newMatch.kind.singles'), hint: '1 v 1' },
		{ value: 'doubles', label: t('newMatch.kind.doubles'), hint: '2 v 2' },
		{ value: 'team', label: t('newMatch.kind.team'), hint: t('newMatch.hint.team') }
	]);
	// Big name on top of each side's card
	const sideTitle = (side: Side) =>
		form.kind === 'team'
			? (teamById.get(teamId[side])?.name ?? t('newMatch.pickTeam'))
			: lineup[side].slice(0, perSide).filter(Boolean).map(nameOf).join(' / ') || t('newMatch.pickPlayer');
	// Game order split in rounds: 1v1.., then 1v2.., ...
	const rounds = $derived(
		Array.from({ length: TEAM_SIZE }, (_, r) =>
			pairings.slice(r * TEAM_SIZE, (r + 1) * TEAM_SIZE).map(([h, a], i) => ({ h, a, n: r * TEAM_SIZE + i }))
		)
	);
	const canCreate = $derived(
		form.kind === 'team'
			? teamsReady && teamTables.length > 0
			: SIDES.every((side) => lineup[side].slice(0, perSide).every(Boolean)) && !!form.pool_table_id
	);

	// ---- Submit ----

	async function create(e: SubmitEvent) {
		e.preventDefault();
		saving = true;
		await run(async () => {
			const base = { game_type_id: form.game_type_id, kind: form.kind, name: form.name.trim() || undefined };
			if (form.kind === 'team') {
				await api('/matches', {
					body: { ...base, race_to: raceTo, pool_table_ids: teamTables, home_team_id: teamId.home, away_team_id: teamId.away, home_order: starters('home'), away_order: starters('away'),
						home_reserves: reservesOf('home'), away_reserves: reservesOf('away') }
				});
				// Several tables: follow them all from the live view
				await goto(teamTables.length === 1 ? `/score/${teamTables[0]}` : '/dashboard');
			} else {
				await api('/matches', {
					body: { ...base, target: form.target, pool_table_id: form.pool_table_id, home: lineup.home.slice(0, perSide), away: lineup.away.slice(0, perSide) }
				});
				await goto(`/score/${form.pool_table_id}`);
			}
		});
		saving = false;
	}
</script>

{#snippet stepHead(n: number, title: string)}
	<div class="mb-3 flex items-center gap-3">
		<span class="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-gold-100 font-condensed text-sm font-bold text-gold-700 ring-1 ring-gold-200">{n}</span>
		<h2 class="font-condensed! text-[15px] font-bold! tracking-[0.16em]! text-gray-900 uppercase">{title}</h2>
		<span class="h-px flex-1 bg-gray-300/70"></span>
	</div>
{/snippet}

{#snippet kindIcon(kind: Kind)}
	<svg viewBox="0 0 24 24" class="h-6 w-6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
		{#if kind === 'singles'}
			<circle cx="12" cy="8" r="3.5" /><path d="M5 20c0-3.9 3.1-6.5 7-6.5s7 2.6 7 6.5" />
		{:else if kind === 'doubles'}
			<circle cx="8.5" cy="8.5" r="3" /><path d="M2.5 19.5c0-3.3 2.7-5.5 6-5.5s6 2.2 6 5.5" />
			<circle cx="16.5" cy="7" r="2.6" /><path d="M15.2 12.7c.4-.1.9-.2 1.3-.2 2.9 0 5 2 5 5" />
		{:else}
			<path d="M7 4h10v4a5 5 0 0 1-10 0V4Z" /><path d="M7 6H4.5a2.5 2.5 0 0 0 2.6 3.5M17 6h2.5a2.5 2.5 0 0 1-2.6 3.5" />
			<path d="M12 13v3.5M8.5 20h7M9.5 20l.8-3.5h3.4l.8 3.5" />
		{/if}
	</svg>
{/snippet}

{#snippet stepper(value: number, set: (v: number) => void, max: number = Infinity)}
	<div class="mt-2 inline-flex items-center gap-1 rounded-full border border-gray-200 bg-gray-50 p-1">
		<button type="button" class="step" disabled={value <= 1} onclick={() => set(Math.max(1, value - 1))} aria-label={t('common.less')}>−</button>
		<input class="number w-16 bg-transparent text-center font-display text-2xl font-extrabold tabular-nums outline-none" type="number" min="1" {max}
			{value} oninput={(e) => { const v = Number(e.currentTarget.value); if (v >= 1) set(Math.min(max, v)); }} />
		<button type="button" class="step" disabled={value >= max} onclick={() => set(Math.min(max, value + 1))} aria-label={t('common.more')}>+</button>
	</div>
{/snippet}

<form class="mx-auto max-w-4xl pb-32" onsubmit={create}>
	<!-- Hero -->
	<header class="mb-8">
		<p class="eyebrow mb-1">{t('newMatch.eyebrow')}</p>
		<h1 class="page-title">{t('newMatch.title')}</h1>
		<p class="mt-2 text-gray-500">{t('newMatch.subtitle')}</p>
	</header>

	<!-- 1. Format -->
	<section class="mb-8">
		{@render stepHead(1, t('newMatch.step.format'))}
		<div class="grid grid-cols-3 gap-3">
			{#each KINDS as k (k.value)}
				{@const on = form.kind === k.value}
				<button type="button" aria-pressed={on} onclick={() => (form.kind = k.value)}
					class="opt group" class:opt-on={on}>
					<span class="opt-icon">{@render kindIcon(k.value)}</span>
					<span class="opt-label">{k.label}</span>
					<span class="opt-hint">{k.hint}</span>
					{#if on}<span class="opt-check">✓</span>{/if}
				</button>
			{/each}
		</div>
	</section>

	<!-- 2. Rules and table -->
	<section class="mb-8">
		{@render stepHead(2, form.kind === 'team' ? t('newMatch.step.setupTeam') : t('newMatch.step.setup'))}
		<div class="card divide-y divide-gray-100">
			<label class="block p-6">
				<span class="lbl">{t('newMatch.name')} <span class="font-normal text-gray-500">{t('newMatch.nameHint')}</span></span>
				<input class="field" maxlength="80" placeholder={t('newMatch.namePh')} bind:value={form.name} />
			</label>
			<div class="grid gap-6 p-6 sm:grid-cols-[1fr_auto]">
				<div>
					<span class="lbl">{t('common.game')}</span>
					<div class="mt-2 flex flex-wrap gap-2">
						{#each gameTypes as g (g.id)}
							{@const on = form.game_type_id === g.id}
							<button type="button" aria-pressed={on} onclick={() => pickGame(g.id)}
								class="rounded-xl border px-4 py-2 text-sm font-semibold transition {on ? 'border-gold-400 bg-gold-100/40 text-gray-900 ring-4 ring-gold-300/20' : 'border-gray-200 bg-white text-gray-700 hover:border-gray-300 hover:shadow-sm'}">
								{g.name}
							</button>
						{/each}
					</div>
				</div>

				<div>
					<span class="lbl">
						{#if form.kind === 'team'}{t('newMatch.teamRaceTo')}{:else}{gameType?.scoring_mode === 'points' ? t('common.pointsToWin') : t('newMatch.raceTo')}{/if}
					</span>
					{#if form.kind === 'team'}
						{@render stepper(raceTo, (v) => (raceTo = v), pairings.length)}
						<p class="mt-1 text-xs text-gray-500">{t('newMatch.ofGames', { n: pairings.length })}</p>
					{:else}
						{@render stepper(form.target, (v) => (form.target = v))}
					{/if}
				</div>
			</div>

			<div class="p-6">
				<span class="lbl">
					{form.kind === 'team' ? t('newMatch.tables') : t('newMatch.table')}
					{#if form.kind === 'team'}<span class="font-normal text-gray-500">{t('newMatch.tablesHint')}</span>{/if}
				</span>
				<div class="mt-3 grid grid-cols-2 gap-2.5 sm:grid-cols-4">
					{#each tables as x (x.id)}
						{@const n = teamTables.indexOf(x.id)}
						{@const on = form.kind === 'team' ? n >= 0 : form.pool_table_id === x.id}
						{@const busy = x.current_match?.status === 'live'}
						<button type="button" aria-pressed={on} onclick={() => (form.kind === 'team' ? toggleTable(x.id) : (form.pool_table_id = x.id))}
							class="relative flex items-center gap-3 rounded-xl border px-3 py-3 text-left transition {on ? 'border-gold-400 bg-gold-100/60 ring-4 ring-gold-300/25' : 'border-gray-200 bg-white hover:border-gray-300 hover:shadow-sm'}">
							<!-- A tiny table seen from above -->
							<span class="relative h-6 w-10 shrink-0 rounded-[6px] border-[3px] {on ? 'border-gold-400 bg-gold-200' : 'border-gray-300 bg-gray-100'}">
								<span class="absolute -top-1 -right-1 h-2.5 w-2.5 rounded-full ring-2 ring-white {busy ? 'bg-red-500' : 'bg-gold-400'}"></span>
							</span>
							<span class="min-w-0">
								<span class="block truncate font-semibold">{x.name}</span>
								<span class="block text-xs font-normal {busy ? 'text-red-600' : 'text-gray-500'}">{busy ? t('newMatch.playing') : t('common.free')}</span>
							</span>
							{#if form.kind === 'team' && n >= 0}
								<span class="absolute -top-2 -right-2 grid h-6 w-6 place-items-center rounded-full bg-black text-xs font-bold text-gold-300 shadow">{n + 1}</span>
							{/if}
						</button>
					{:else}
						<p class="col-span-full rounded-xl border-2 border-dashed border-gray-200 px-4 py-5 text-center text-sm text-gray-500">
							{t('newMatch.noTables')} <a class="font-semibold underline decoration-gold-400 underline-offset-2" href="/tables">{t('nav.tables')}</a>.
						</p>
					{/each}
				</div>
			</div>
		</div>
	</section>

	<!-- 3. Sides -->
	<section class="mb-8">
		{@render stepHead(3, form.kind === 'team' ? t('newMatch.step.teams') : t('newMatch.step.players'))}
		<div class="relative grid gap-4 md:grid-cols-2">
			<div class="pointer-events-none absolute inset-x-0 top-5 z-10 hidden justify-center md:flex">
				<span class="grid h-12 w-12 place-items-center rounded-full bg-white font-condensed text-lg font-bold tracking-wider text-gray-500 shadow-md ring-4 ring-gray-100">VS</span>
			</div>

			{#each SIDES as side (side)}
				{@const c = sideColor(side)}
				<div class="card overflow-hidden">
					<div class="border-t-4 border-b border-b-gray-100 px-5 py-4 {side === 'away' ? 'md:text-right' : ''}"
						style:border-top-color={c} style:background="color-mix(in oklab, {c} 5%, white)">
						<div class="font-condensed text-xs font-bold tracking-[0.2em] uppercase" style:color={c}>{t(`side.${side}`)}</div>
						<div class="truncate font-display text-xl font-extrabold text-gray-900">{sideTitle(side)}</div>
					</div>
					<div class="p-5">
						{#if form.kind !== 'team'}
							<div class="space-y-2.5">
								{#each Array(perSide) as _, i (i)}
									{@const key = `${side}-${i}`}
									{#if newPlayer[key] != null}
										<div class="flex gap-2">
											<input class="field mt-0! flex-1" placeholder={t('newMatch.newPlayerPh')} bind:value={newPlayer[key]}
												onkeydown={(e) => e.key === 'Enter' && (e.preventDefault(), addPlayerToSlot(side, i))} />
											<button type="button" class="btn btn-primary btn-sm" onclick={() => addPlayerToSlot(side, i)}>{t('common.add')}</button>
											<button type="button" class="btn btn-ghost btn-sm px-3" onclick={() => (newPlayer[key] = null)} aria-label={t('common.cancel')}>✕</button>
										</div>
									{:else}
										<div class="flex items-center gap-3">
											<span class="avatar" style:background={lineup[side][i] ? c : undefined}>
												{lineup[side][i] ? initials(nameOf(lineup[side][i])) : '?'}
											</span>
											<select class="field mt-0! flex-1" value={lineup[side][i]}
												onchange={(e) => {
													const v = e.currentTarget.value;
													if (v === 'new') { newPlayer[key] = ''; e.currentTarget.value = String(lineup[side][i]); }
													else lineup[side][i] = Number(v);
												}}>
												<option value={0} disabled>{t('newMatch.pickPlayer')}</option>
												{#each players as p (p.id)}<option value={p.id}>{p.name}</option>{/each}
												<option value="new">{t('newMatch.newPlayerOpt')}</option>
											</select>
										</div>
									{/if}
								{/each}
							</div>
						{:else}
							{#if newTeam[side] != null}
								<div class="flex gap-2">
									<input class="field mt-0! flex-1" placeholder={t('newMatch.newTeamPh')} bind:value={newTeam[side]}
										onkeydown={(e) => e.key === 'Enter' && (e.preventDefault(), createTeam(side))} />
									<button type="button" class="btn btn-primary btn-sm" onclick={() => createTeam(side)}>{t('common.create')}</button>
									<button type="button" class="btn btn-ghost btn-sm px-3" onclick={() => (newTeam[side] = null)} aria-label={t('common.cancel')}>✕</button>
								</div>
							{:else}
								<select class="field mt-0! font-semibold" value={teamId[side]}
									onchange={(e) => {
										const v = e.currentTarget.value;
										if (v === 'new') { newTeam[side] = ''; e.currentTarget.value = String(teamId[side]); }
										else pickTeam(side, Number(v));
									}}>
									<option value={0} disabled>{t('newMatch.pickTeam')}</option>
									{#each teams as x (x.id)}<option value={x.id} disabled={x.id === teamId[side === 'home' ? 'away' : 'home']}>{x.name}</option>{/each}
									<option value="new">{t('newMatch.newTeamOpt')}</option>
								</select>
							{/if}

							{#if teamId[side]}
								<ol class="mt-4 space-y-1.5">
									{#each picked[side] as pid, i (pid)}
										{@const reserve = i >= TEAM_SIZE}
										{#if i === TEAM_SIZE}
											<li class="flex items-center gap-2 pt-2 font-condensed text-xs font-bold tracking-[0.16em] text-gold-600 uppercase">
												<span class="h-px flex-1 bg-gold-200"></span>{t('newMatch.replacements')}<span class="h-px flex-1 bg-gold-200"></span>
											</li>
										{/if}
										<li class="group flex items-center gap-3 rounded-xl px-2 py-1.5 transition {reserve ? 'bg-gold-100/50' : 'bg-gray-50 hover:bg-gray-100'}">
											<span class="w-7 text-center font-condensed text-base font-bold {reserve ? 'text-gold-600' : 'text-gray-400'}">
												{reserve ? t('newMatch.reserveTag', { n: i - TEAM_SIZE + 1 }) : `${i + 1}º`}
											</span>
											<span class="avatar" style:background={reserve ? '#cc8a10' : c}>{initials(nameOf(pid))}</span>
											<span class="flex-1 truncate font-medium">{nameOf(pid)}</span>
											<span class="flex opacity-50 transition group-hover:opacity-100">
												<button type="button" class="icon-btn" disabled={i === 0} onclick={() => move(side, i, -1)} aria-label={t('common.moveUp')}>↑</button>
												<button type="button" class="icon-btn" disabled={i === picked[side].length - 1} onclick={() => move(side, i, 1)} aria-label={t('common.moveDown')}>↓</button>
												<button type="button" class="icon-btn hover:text-red-600" onclick={() => picked[side].splice(i, 1)} aria-label={t('common.remove')}>✕</button>
											</span>
										</li>
									{:else}
										<li class="rounded-xl border-2 border-dashed border-gray-200 px-3 py-5 text-center text-sm text-gray-400">{t('newMatch.noPlayers')}</li>
									{/each}
									{#each Array(Math.max(0, TEAM_SIZE - picked[side].length)) as _, i (i)}
										{#if picked[side].length > 0}
											<li class="flex items-center gap-3 rounded-xl border-2 border-dashed border-gray-200 px-2 py-1.5 text-sm text-gray-400">
												<span class="w-7 text-center font-condensed text-base font-bold">{picked[side].length + i + 1}º</span>
												<span>{t('newMatch.emptySlot')}</span>
											</li>
										{/if}
									{/each}
								</ol>

								{#if bench(side).length}
									<div class="mt-5 font-condensed text-xs font-bold tracking-[0.16em] text-gray-400 uppercase">{t('newMatch.restRoster')}</div>
									<div class="mt-2 flex flex-wrap gap-1.5">
										{#each bench(side) as p (p.id)}
											<button type="button" class="chip" disabled={picked[side].length >= MAX_PICKED} onclick={() => picked[side].push(p.id)}>
												<span class="text-gold-500">＋</span> {p.display_name}
											</button>
										{/each}
									</div>
								{/if}

								{#if newPlayer[side] != null}
									<div class="mt-4 flex gap-2">
										<input class="field mt-0! flex-1" placeholder={t('newMatch.newPlayerPh')} bind:value={newPlayer[side]}
											onkeydown={(e) => e.key === 'Enter' && (e.preventDefault(), addPlayerToTeam(side))} />
										<button type="button" class="btn btn-primary btn-sm" onclick={() => addPlayerToTeam(side)}>{t('common.add')}</button>
										<button type="button" class="btn btn-ghost btn-sm px-3" onclick={() => (newPlayer[side] = null)} aria-label={t('common.cancel')}>✕</button>
									</div>
								{:else}
									<button type="button" class="mt-4 text-sm font-semibold text-gray-900 underline decoration-gold-400 decoration-2 underline-offset-4 hover:text-gold-600" onclick={() => (newPlayer[side] = '')}>
										{t('newMatch.newPlayerInTeam')}
									</button>
								{/if}
							{/if}
						{/if}
					</div>
				</div>
			{/each}
		</div>
	</section>

	<!-- 4. Game order -->
	{#if form.kind === 'team' && teamsReady}
		<section class="mb-8">
			{@render stepHead(4, t('newMatch.gameOrder'))}
			<div class="card p-6">
				<p class="mb-4 text-sm text-gray-500">{t('newMatch.orderUpTo', { n: pairings.length })} <b class="text-gray-900">{raceTo}</b> {t('newMatch.orderWins')}</p>
				<div class="grid gap-5 sm:grid-cols-2">
					{#each rounds as round, r (r)}
						<div>
							<div class="mb-2 font-condensed text-xs font-bold tracking-[0.16em] text-gray-400 uppercase">{t('newMatch.round', { n: r + 1 })}</div>
							<ol class="space-y-1">
								{#each round as g (g.n)}
									<li class="flex items-center gap-2 rounded-lg bg-gray-50 px-2.5 py-1.5 text-sm">
										<span class="w-5 font-mono text-xs text-gray-400">{g.n + 1}</span>
										<span class="flex-1 truncate text-right font-medium">
											{nameOf(picked.home[g.h])} <span class="font-mono text-xs" style:color={sideColor('home')}>{g.h + 1}º</span>
										</span>
										<span class="font-condensed text-xs font-bold text-gray-400 uppercase">{t('common.vs')}</span>
										<span class="flex-1 truncate font-medium">
											<span class="font-mono text-xs" style:color={sideColor('away')}>{g.a + 1}º</span> {nameOf(picked.away[g.a])}
										</span>
										{#if teamTables.length > 1}
											<span class="rounded bg-white px-1.5 text-[10px] font-semibold text-gray-500 ring-1 ring-gray-200">{tableOf(g.n)}</span>
										{/if}
									</li>
								{/each}
							</ol>
						</div>
					{/each}
				</div>
			</div>
		</section>
	{/if}

	<!-- Create -->
	<div class="fixed inset-x-0 bottom-0 z-20 border-t border-gray-200 bg-white/90 shadow-[0_-12px_32px_-16px_rgb(0_0_0/0.15)] backdrop-blur-md">
		<div class="mx-auto flex max-w-4xl items-center gap-4 px-4 py-3.5">
			<div class="min-w-0 flex-1 text-sm">
				{#if error}
					<p class="font-medium text-red-600">{error}</p>
				{:else}
					<p class="flex min-w-0 items-center gap-2 font-display font-bold">
						<span class="h-2.5 w-2.5 shrink-0 rounded-full" style:background={sideColor('home')}></span>
						<span class="truncate">
							{#if form.kind === 'team'}
								{teamById.get(teamId.home)?.name ?? t('side.home')} <span class="px-1 font-condensed text-gray-400 uppercase">{t('common.vs')}</span> {teamById.get(teamId.away)?.name ?? t('side.away')}
							{:else}
								{lineup.home.slice(0, perSide).filter(Boolean).map(nameOf).join(' / ') || t('side.home')} <span class="px-1 font-condensed text-gray-400 uppercase">{t('common.vs')}</span> {lineup.away.slice(0, perSide).filter(Boolean).map(nameOf).join(' / ') || t('side.away')}
							{/if}
						</span>
						<span class="h-2.5 w-2.5 shrink-0 rounded-full" style:background={sideColor('away')}></span>
					</p>
					<p class="mt-0.5 truncate text-gray-500">
						{gameType?.name ?? ''} · {form.kind === 'team' ? t('newMatch.summaryTeam', { n: raceTo }) : gameType?.scoring_mode === 'points' ? t('newMatch.summaryTo', { n: form.target }) : t('common.raceToLower', { n: form.target })}
					</p>
				{/if}
			</div>
			<button class="btn btn-primary px-6 py-3" disabled={saving || !canCreate}>
				{saving ? t('newMatch.creating') : form.kind === 'team' && teamTables.length > 1 ? t('newMatch.createLive') : t('newMatch.createTable')}
				{#if !saving}<span aria-hidden="true">→</span>{/if}
			</button>
		</div>
	</div>
</form>

<style lang="postcss">
	@reference "../../../../app.css";

	/* Big selectable cards for the format */
	.opt {
		@apply relative flex flex-col items-start rounded-2xl border border-gray-200 bg-white p-3 text-left transition duration-200 hover:-translate-y-0.5 hover:border-gray-300 hover:shadow-md sm:p-5;
	}
	.opt-on {
		@apply border-gold-400 bg-gold-100/40 shadow-sm ring-4 ring-gold-300/20 hover:translate-y-0 hover:border-gold-400 hover:shadow-sm;
	}
	.opt-icon {
		@apply grid h-11 w-11 place-items-center rounded-xl bg-gray-100 text-gray-600 transition group-hover:bg-gold-100;
	}
	.opt-on .opt-icon {
		@apply bg-gold-300/80 text-gray-900;
	}
	.opt-label {
		@apply mt-3 font-display leading-tight font-bold sm:text-lg;
	}
	.opt-hint {
		@apply mt-0.5 font-condensed text-xs tracking-wider text-gray-500 uppercase;
	}
	.opt-on .opt-hint {
		@apply text-gold-600;
	}
	.opt-check {
		@apply absolute top-3 right-3 grid h-5 w-5 place-items-center rounded-full bg-gold-400 text-[11px] font-black text-white;
	}
	.step {
		@apply grid h-10 w-10 place-items-center rounded-full bg-white text-lg font-bold text-gray-800 shadow-sm ring-1 ring-gray-200 transition hover:bg-gold-100 hover:ring-gold-400 active:scale-95 disabled:opacity-30 disabled:hover:bg-white disabled:hover:text-gray-800 disabled:hover:ring-gray-200;
	}
	.number {
		appearance: textfield;
		-moz-appearance: textfield;
	}
	.number::-webkit-inner-spin-button,
	.number::-webkit-outer-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}
	.avatar {
		@apply grid h-9 w-9 shrink-0 place-items-center rounded-full bg-gray-300 text-xs font-bold text-white shadow-sm ring-2 ring-white;
	}
	.icon-btn {
		@apply grid h-7 w-7 place-items-center rounded-lg text-gray-500 transition hover:bg-white hover:shadow-sm disabled:opacity-25 disabled:hover:bg-transparent disabled:hover:shadow-none;
	}
	.chip {
		@apply rounded-full border border-gray-200 bg-white px-3 py-1 text-xs font-medium transition hover:border-gold-400 hover:bg-gold-100 disabled:opacity-40;
	}
</style>
