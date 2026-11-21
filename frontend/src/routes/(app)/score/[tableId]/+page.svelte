<!--
  Scoring screen of one table, made for a tablet/phone at the table (the
  Android app). Every tap goes straight to the server; with no connection
  the buttons are disabled.
-->
<script lang="ts">
	import { page } from '$app/state';
	import { api, photoUrl } from '#lib/api.ts';
	import { errorMessage, roundLabel } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { live } from '#lib/live.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import { raceLabel } from '#lib/overlay/state.svelte.ts';
	import type { Fixture, Match, PoolTable, Side } from '#lib/types.ts';
	import { downloadSheet } from '#lib/sheet/index.ts';

	const tableId = $derived(Number(page.params.tableId));
	let table = $state<PoolTable | null>(null);
	let busy = $state(false);
	let error = $state('');
	let points = $state(1);
	let breaker = $state<Side>('home');
	// Who breaks the next match: what the match says (team matches alternate by round), else home
	const nextMatch = $derived(table?.queue?.[0] ?? null);
	let breakerFor = 0;
	$effect(() => {
		if (nextMatch && nextMatch.id !== breakerFor) {
			breakerFor = nextMatch.id;
			breaker = nextMatch.breaking_side ?? 'home';
		}
	});

	const m = $derived(table?.current_match ?? null);
	const playing = $derived(m?.status === 'live');
	const disabled = $derived(busy || !live.connected);
	const pointsMode = $derived(m?.game_type.scoring_mode === 'points');

	async function load() {
		table = await api<PoolTable>(`/pool_tables/${tableId}`);
	}

	$effect(() => {
		load();
		let timer: ReturnType<typeof setTimeout>;
		const off = live.on((msg) => {
			if (msg.type === 'table' && msg.table.id === tableId) table = { ...table, ...msg.table };
			if (msg.type === 'match' && msg.match.pool_table_id === tableId && msg.match.status === 'scheduled') {
				// Creating a team match queues many games at once; reload once
				clearTimeout(timer);
				timer = setTimeout(load, 150);
			}
		}, load);
		return () => {
			clearTimeout(timer);
			off();
		};
	});

	// Keep the screen on while scoring
	$effect(() => {
		let lock: WakeLockSentinel | null = null;
		navigator.wakeLock?.request('screen').then((l) => (lock = l)).catch(() => {});
		return () => lock?.release();
	});

	// Full screen (hides the browser and system bars). Safari on iPad only has the webkit-prefixed API.
	type FsDoc = Document & { webkitFullscreenElement?: Element; webkitFullscreenEnabled?: boolean; webkitExitFullscreen?: () => void };
	type FsEl = HTMLElement & { webkitRequestFullscreen?: () => void };
	const fsDoc = document as FsDoc;
	const canFullscreen = !!(fsDoc.fullscreenEnabled || fsDoc.webkitFullscreenEnabled);
	let fullscreen = $state(false);
	$effect(() => {
		const sync = () => (fullscreen = !!(fsDoc.fullscreenElement || fsDoc.webkitFullscreenElement));
		sync();
		document.addEventListener('fullscreenchange', sync);
		document.addEventListener('webkitfullscreenchange', sync);
		return () => {
			document.removeEventListener('fullscreenchange', sync);
			document.removeEventListener('webkitfullscreenchange', sync);
		};
	});
	function enterFullscreen() {
		if (!canFullscreen || fullscreen) return;
		const el = document.documentElement as FsEl;
		try {
			if (el.requestFullscreen) el.requestFullscreen({ navigationUI: 'hide' }).catch(() => {});
			else el.webkitRequestFullscreen?.();
		} catch {
			/* not allowed here; the button stays */
		}
	}
	function toggleFullscreen() {
		if (!fullscreen) return enterFullscreen();
		if (fsDoc.exitFullscreen) fsDoc.exitFullscreen().catch(() => {});
		else fsDoc.webkitExitFullscreen?.();
	}

	async function act(path: string, body?: unknown) {
		busy = true;
		error = '';
		try {
			await api(path, { body: body ?? {} });
			await load();
		} catch (e) {
			error = errorMessage(e);
		} finally {
			busy = false;
		}
	}

	// Standalone team match: after each round (4 games with 4 players a side)
	// the scorer gets a card to make substitutions before the next game.
	let fixture = $state<Fixture | null>(null);
	let subsDone = $state<string[]>([]);
	const fixtureId = $derived(!playing && nextMatch?.team_match ? nextMatch.fixture_id : null);
	$effect(() => {
		const id = fixtureId;
		if (!id) return void (fixture = null);
		const loadFixture = () => api<Fixture>(`/fixtures/${id}`).then((f) => (fixture = f)).catch(() => {});
		loadFixture();
		return live.on((msg) => {
			if (msg.type === 'fixture' && msg.fixture.id === id) fixture = msg.fixture;
		}, loadFixture);
	});
	const subsKey = $derived.by(() => {
		const f = fixture;
		const size = f?.home?.lineup?.slots.length ?? 0;
		if (!f || !size || !f.away?.lineup || !(f.status === 'ready' || f.status === 'live')) return null;
		const matches = f.matches ?? [];
		const played = matches.filter((x) => x.status === 'finished').length;
		if (!played || played % size || !matches.some((x) => x.status === 'scheduled')) return null;
		return `${f.id}:${played}`;
	});
	const showSubs = $derived(!!subsKey && !subsDone.includes(subsKey));
	async function substitute(side: Side, slot: number, playerId: string) {
		if (!playerId || !fixture) return;
		busy = true;
		error = '';
		try {
			fixture = await api<Fixture>(`/fixtures/${fixture.id}/substitute`, { body: { side, slot, player_id: Number(playerId) } });
			await load(); // the next games on this table now show the new player
		} catch (e) {
			error = errorMessage(e);
		} finally {
			busy = false;
		}
	}

	const score = (side: Side, pts = 1) => act(`/matches/${m!.id}/score`, { side, points: pts });
	const undo = () => act(`/matches/${m!.id}/undo`);
	const concede = (winner: Side) => confirm(t('score.confirmConcede', { name: m![winner].name })) && act(`/matches/${m!.id}/finish`, { winner_side: winner });
	const start = (next: Match) => (enterFullscreen(), act(`/matches/${next.id}/start`, { pool_table_id: tableId, breaking_side: breaker }));
	const clear = () => act(`/pool_tables/${tableId}/clear`);

	// Game sheet (PDF): of the whole team match for a rubber, else of the match
	let sheetBusy = $state(false);
	async function sheet(match: Match) {
		sheetBusy = true;
		error = '';
		try {
			if (match.team_match && match.fixture_id) {
				const f = await api<Fixture>(`/fixtures/${match.fixture_id}`);
				await downloadSheet({ team: true, fixture: f, tournamentName: match.name ?? match.tournament?.name, winCondition: match.team_match.win_condition });
			} else {
				await downloadSheet({ match });
			}
		} catch (e) {
			error = errorMessage(e);
		} finally {
			sheetBusy = false;
		}
	}

	const SIDES = ['home', 'away'] as const;
	const SIDE_COLOR: Record<Side, string> = { home: '#1e5aa8', away: '#b0302a' };
	const colorOf = (_match: Match, side: Side) => SIDE_COLOR[side];
	const teamOf = (match: Match, side: Side) => match.team_match?.[side].name ?? null;
	const initials = (name: string) =>
		name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
	const metaOf = (match: Match) =>
		[match.name ?? match.tournament?.name, match.round_label?.key === 'friendly' ? null : roundLabel(match.round_label), match.team_match && match.rubber_number ? t('score.game', { n: match.rubber_number }) : null, match.game_type.name]
			.filter(Boolean)
			.join(' · ');
</script>

{#snippet trophy(cls: string)}
	<svg viewBox="0 0 24 24" class={cls} fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
		<path d="M7 4h10v4a5 5 0 0 1-10 0V4Z" /><path d="M7 6H4.5a2.5 2.5 0 0 0 2.6 3.5M17 6h2.5a2.5 2.5 0 0 1-2.6 3.5" />
		<path d="M12 13v3.5M8.5 20h7M9.5 20l.8-3.5h3.4l.8 3.5" />
	</svg>
{/snippet}

{#snippet players(match: Match, side: Side, size: 'lg' | 'sm')}
	{#if match[side].players.length}
		<div class="flex flex-col gap-2 {size === 'lg' ? 'items-center' : ''}">
			{#each match[side].players as p (p.id)}
				<div class="flex items-center gap-3 {size === 'lg' ? 'flex-col sm:flex-row' : ''}">
					{#if p.photo_url}
						<img src={photoUrl(p.photo_url)} alt="" loading="lazy"
							class="shrink-0 rounded-full object-cover {size === 'lg' ? 'h-14 w-14 ring-4 ring-white/10' : 'h-9 w-9 ring-2 ring-white/10'}"
							style:background={colorOf(match, side)} />
					{:else}
						<span class="grid shrink-0 place-items-center rounded-full font-black text-white
							{size === 'lg' ? 'h-14 w-14 text-xl ring-4 ring-white/10' : 'h-9 w-9 text-sm ring-2 ring-white/10'}"
							style:background={colorOf(match, side)}>
							{initials(p.display_name)}
						</span>
					{/if}
					<span class="min-w-0 {size === 'lg' ? 'text-center sm:text-left' : ''}">
						<span class="block truncate {size === 'lg' ? 'font-display text-3xl font-extrabold sm:text-4xl' : 'font-semibold'}">{p.display_name}</span>
						{#if p.name !== p.display_name}
							<span class="block truncate {size === 'lg' ? 'text-base opacity-75' : 'text-xs text-white/60'}">{p.name}</span>
						{/if}
					</span>
				</div>
			{/each}
		</div>
	{:else}
		<span class="font-bold {size === 'lg' ? 'text-3xl' : ''}">{match[side].name}</span>
	{/if}
{/snippet}

{#snippet sectionHead(title: string)}
	<div class="mb-3 flex items-center gap-3">
		<h2 class="font-condensed! text-[15px] font-bold! tracking-[0.16em]! text-white/80 uppercase">{title}</h2>
		<span class="h-px flex-1 bg-white/10"></span>
	</div>
{/snippet}

<div class="surface-dark safe flex min-h-dvh flex-col text-white select-none">
<div class="mx-auto flex w-full max-w-screen-2xl flex-1 flex-col">
	<!-- Header, like the other pages -->
	<header class="flex flex-wrap gap-x-4 gap-y-3 {playing ? 'mb-3 items-center' : 'mb-6 items-end'}">
		<a href="/dashboard" class="{playing ? '' : 'mb-1'} grid h-10 w-10 shrink-0 place-items-center rounded-full text-white/70 ring-1 ring-white/15 transition hover:text-gold-300 hover:ring-gold-300/40" aria-label={t('common.back')}>←</a>
		<div class="min-w-0">
			{#if !playing}<p class="eyebrow mb-1 text-gold-300!">{t('score.eyebrow')}</p>{/if}
			<div class="flex items-center gap-3">
				<h1 class="{playing ? 'truncate font-display text-2xl font-extrabold' : 'page-title'} text-white!">{table?.name ?? '…'}</h1>
				<span class="badge {live.connected ? (playing ? 'badge-live' : 'bg-white/10 text-white/80') : 'bg-red-500/20 text-red-300'}">
					{#if !playing || !live.connected}<span class="h-2 w-2 rounded-full {live.connected ? 'bg-gold-300' : 'bg-red-500'}"></span>{/if}
					{live.connected ? (playing ? t('common.live') : t('score.online')) : t('score.offline')}
				</span>
			</div>
		</div>
		<span class="ml-auto flex items-center gap-3 {playing ? '' : 'mb-1'}">
			{#if m && playing}
				<span class="flex flex-wrap justify-end gap-1.5">
					{#each [metaOf(m), raceLabel(m)] as chip (chip)}
						<span class="badge text-white/70 ring-1 ring-white/15">{chip}</span>
					{/each}
				</span>
			{/if}
			{#if canFullscreen}
				<button class="grid h-10 w-10 shrink-0 place-items-center rounded-full text-white/70 ring-1 ring-white/15 transition hover:text-gold-300 hover:ring-gold-300/40"
					onclick={toggleFullscreen} aria-label={t(fullscreen ? 'score.exitFullscreen' : 'score.fullscreen')} title={t(fullscreen ? 'score.exitFullscreen' : 'score.fullscreen')}>
					<svg viewBox="0 0 24 24" class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
						{#if fullscreen}
							<path d="M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5" />
						{:else}
							<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5" />
						{/if}
					</svg>
				</button>
			{/if}
		</span>
	</header>

	{#if error}<p class="mb-4 rounded-xl border border-red-500/30 bg-red-500/15 px-4 py-2.5 text-sm font-medium text-red-200">{error}</p>{/if}

	{#if m && playing}
		{@const tm = m.team_match}
		{#if tm}
			<!-- Team race -->
			<div class="card-dark mb-3 px-5 py-3">
				<div class="flex items-center gap-3">
					<span class="flex-1 truncate text-right text-lg font-bold" style:color={colorOf(m, 'home')}>{tm.home.name}</span>
					<span class="rounded-xl bg-white/10 px-3 py-1 font-display text-2xl font-extrabold tabular-nums ring-1 ring-white/10">{tm.home.score} – {tm.away.score}</span>
					<span class="flex-1 truncate text-lg font-bold" style:color={colorOf(m, 'away')}>{tm.away.name}</span>
				</div>
				{#if tm.target}
					<div class="mt-2 flex items-center gap-2 text-xs text-white/70">
						<div class="flex h-1.5 flex-1 justify-end overflow-hidden rounded-full bg-white/10">
							<div class="h-full rounded-full transition-all" style:width="{(tm.home.score / tm.target) * 100}%" style:background={colorOf(m, 'home')}></div>
						</div>
						<span class="shrink-0 font-semibold">{t('common.raceToLower', { n: tm.target })}</span>
						<div class="flex h-1.5 flex-1 overflow-hidden rounded-full bg-white/10">
							<div class="h-full rounded-full transition-all" style:width="{(tm.away.score / tm.target) * 100}%" style:background={colorOf(m, 'away')}></div>
						</div>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Scoring panels -->
		<div class="grid min-h-[45vh] flex-1 grid-cols-2 gap-4">
			{#each SIDES as side (side)}
				{@const breaks = m.breaking_side === side}
				<button
					class="panel relative flex h-full flex-col items-center justify-between overflow-hidden rounded-2xl p-5 transition active:scale-[0.98] disabled:opacity-40"
					style:--c={colorOf(m, side)}
					{disabled}
					onclick={() => score(side, pointsMode ? points : 1)}>
					<!-- Soft light of the side's colour from the top -->
					<span class="glow pointer-events-none absolute inset-x-0 top-0 h-2/3"></span>

					<span class="relative flex w-full items-center justify-between font-condensed text-sm font-bold tracking-[0.18em] uppercase">
						<span class="truncate" style:color="color-mix(in oklab, var(--c) 45%, white)">{teamOf(m, side) ?? t(`side.${side}`)}</span>
						{#if breaks}
							<span class="flex items-center gap-1.5 rounded-full bg-gold-300/15 px-2.5 py-1 font-sans text-xs tracking-normal text-gold-300 normal-case ring-1 ring-gold-300/40">
								<span class="h-2 w-2 rounded-full bg-gold-300"></span>{t('score.breaks')}
							</span>
						{/if}
					</span>

					<span class="relative">{@render players(m, side, 'lg')}</span>

					<span class="relative score-num font-display leading-none font-extrabold tabular-nums">{m[side].score}</span>

					<span class="relative flex w-full flex-col items-center gap-2">
						{#if !pointsMode && m.target > 1 && m.target <= 21}
							<span class="flex flex-wrap justify-center gap-1.5">
								{#each Array(m.target) as _, i (i)}
									<span class="h-2.5 w-2.5 rounded-full {i < m[side].score ? '' : 'bg-white/15'}" style:background={i < m[side].score ? 'var(--c)' : null}></span>
								{/each}
							</span>
						{/if}
						<span class="rounded-full bg-white/5 px-3 py-1 text-xs font-semibold text-white/60 ring-1 ring-white/10">
							{pointsMode ? t('score.tapPoints', { points: `${points > 0 ? '+' : ''}${points}` }) : m.target === 1 ? t('score.tapGame') : t('score.tapRack')}
						</span>
					</span>
				</button>
			{/each}
		</div>

		{#if pointsMode}
			<div class="card-dark mt-3 flex flex-wrap items-center justify-center gap-2 p-2">
				<span class="px-2 font-condensed text-sm font-bold tracking-[0.16em] text-white/70 uppercase">{t('score.perTap')}</span>
				{#each [1, 2, 5, 10, 14, -1, -2, -15] as p (p)}
					<button class="min-w-12 rounded-full px-3.5 py-2 font-bold tabular-nums transition
						{points === p ? 'bg-gold-300 text-black' : p < 0 ? 'bg-red-500/15 text-red-300' : 'bg-white/10'}"
						onclick={() => (points = p)}>
						{p > 0 ? `+${p}` : p}
					</button>
				{/each}
			</div>
		{/if}

		<!-- Undo only with something to undo; "X wins" only when a tap doesn't already end the game -->
		{@const canUndo = pointsMode || m.home.score + m.away.score > 0}
		{@const canConcede = pointsMode || m.target > 1}
		{#if canUndo || canConcede}
			<div class="mt-3 flex flex-wrap items-center justify-center gap-2">
				{#if canUndo}
					<button class="btn btn-ghost-dark py-3.5" {disabled} onclick={undo}>
						{t('score.undo')}
					</button>
				{/if}
				{#if canConcede}
					{#each SIDES as side (side)}
						<button class="btn btn-ghost-dark py-3.5" {disabled} onclick={() => concede(side)}>
							{@render trophy('h-4 w-4')}{t('score.wins', { name: m[side].name })}
						</button>
					{/each}
				{/if}
			</div>
		{/if}
	{:else}
		{@const next = nextMatch}
		{@const later = table?.queue?.slice(1) ?? []}
		{#if next}
			{@const tm = next.team_match}
			<!-- Next game: the main thing between games -->
			<section class="card-dark hero mb-6 p-5 sm:p-8">
				<div class="mb-6 flex flex-wrap items-center justify-between gap-x-4 gap-y-2">
					<div>
						<p class="font-condensed text-sm font-bold tracking-[0.18em] text-gold-300 uppercase">{t('score.nextGame')}</p>
						<p class="mt-0.5 text-sm text-white/60">{metaOf(next)} · {raceLabel(next)}</p>
					</div>
					{#if tm}
						<div class="flex items-center gap-2 rounded-full bg-white/5 px-3 py-1.5 text-sm ring-1 ring-white/10">
							<span class="h-2 w-2 rounded-full" style:background={colorOf(next, 'home')}></span>
							<span class="max-w-32 truncate font-semibold">{tm.home.name}</span>
							<span class="font-display font-extrabold tabular-nums">{tm.home.score} – {tm.away.score}</span>
							<span class="max-w-32 truncate font-semibold">{tm.away.name}</span>
							<span class="h-2 w-2 rounded-full" style:background={colorOf(next, 'away')}></span>
							{#if tm.target}<span class="text-white/50">· {t('common.raceToLower', { n: tm.target })}</span>{/if}
						</div>
					{/if}
				</div>

				<div class="grid grid-cols-[1fr_auto_1fr] items-center gap-4 sm:gap-8">
					{#each SIDES as side, j (side)}
						{#if j === 1}<span class="font-condensed text-lg font-extrabold text-white/40 uppercase">{t('common.vs')}</span>{/if}
						<div class="flex min-w-0 flex-col items-center gap-3 text-center">
							{#if teamOf(next, side)}
								<span class="max-w-full truncate font-condensed text-sm font-bold tracking-[0.16em] text-white/60 uppercase">{teamOf(next, side)}</span>
							{/if}
							{@render players(next, side, 'lg')}
						</div>
					{/each}
				</div>

				<div class="mt-8 flex flex-col items-center gap-4 border-t border-white/10 pt-6">
					<div class="flex flex-wrap items-center justify-center gap-3">
						<span class="font-condensed text-sm font-bold tracking-[0.16em] text-white/60 uppercase">{t('score.whoBreaks')}</span>
						<div class="flex rounded-full bg-white/5 p-1 ring-1 ring-white/10">
							{#each SIDES as side (side)}
								<button class="flex items-center gap-2 rounded-full px-5 py-2 font-semibold transition {breaker === side ? 'bg-white/15 text-white' : 'text-white/50 hover:text-white/80'}"
									onclick={() => (breaker = side)}>
									<span class="h-2 w-2 rounded-full" style:background={colorOf(next, side)}></span>{next[side].name}
								</button>
							{/each}
						</div>
					</div>
					<button class="btn btn-primary w-full max-w-sm justify-center py-4 text-lg" {disabled} onclick={() => start(next)}>
						<span class="btn-icon">▶</span>{t('score.start')}
					</button>
					{#if showSubs}
						<a href="#subs" class="text-sm font-semibold text-gold-300 hover:underline">{t('score.subsPending')}</a>
					{/if}
				</div>
			</section>
		{:else}
			<div class="mb-6 flex flex-col items-center gap-4 rounded-2xl border-2 border-dashed border-white/10 p-10 text-center text-white/70">
				<p>{t('score.noQueue')}</p>
				<a class="btn btn-gold" href="/matches/new">{t('score.newMatch')}</a>
			</div>
		{/if}

		{#if showSubs && fixture}
			{@const played = (fixture.matches ?? []).filter((x) => x.status === 'finished').length}
			<div id="subs" class="card-dark mb-6 scroll-mt-4 p-5 sm:p-6">
				<div class="mb-1 flex flex-wrap items-center gap-x-3 gap-y-1">
					<h2 class="font-condensed! text-[15px] font-bold! tracking-[0.16em]! text-gold-300 uppercase">{t('score.subsTitle')}</h2>
					<span class="text-sm text-white/60">{t('score.subsPlayed', { n: played, total: fixture.matches?.length ?? 0 })}</span>
				</div>
				<p class="mb-5 text-sm text-white/70">{t('score.subsHint')}</p>
				<div class="grid gap-4 sm:grid-cols-2">
					{#each SIDES as side (side)}
						{@const lineup = fixture[side]?.lineup}
						<div class="rounded-xl bg-white/[0.03] p-4 ring-1 ring-white/10">
							<div class="mb-3 flex items-center gap-2">
								<span class="h-2.5 w-2.5 rounded-full" style:background={nextMatch ? colorOf(nextMatch, side) : SIDE_COLOR[side]}></span>
								<span class="truncate font-bold">{fixture[side]?.display_name}</span>
							</div>
							<div class="space-y-2">
								{#each lineup?.slots ?? [] as slot, i (i)}
									{@const options = (lineup?.bench ?? []).filter((p) => p.reserve || p.starter_slot === i)}
									<div class="flex items-center gap-3">
										<span class="w-6 font-condensed font-bold text-white/50 tabular-nums">{i + 1}º</span>
										<span class="min-w-0 flex-1 truncate">
											{slot.current.display_name}
											{#if slot.current.id !== slot.starter.id}<span class="text-xs text-white/50">⇄ {slot.starter.display_name}</span>{/if}
										</span>
										{#if options.length}
											<select class="rounded-lg border border-white/15 bg-white/5 px-2 py-1.5 text-sm text-white" value="" {disabled}
												onchange={(e) => substitute(side, i, e.currentTarget.value)} aria-label={t('fixture.substitute')}>
												<option value="" class="text-black">{t('score.subsSwap')}</option>
												{#each options as p (p.id)}<option value={p.id} class="text-black">{p.display_name}</option>{/each}
											</select>
										{/if}
									</div>
								{/each}
							</div>
							<div class="mt-3 border-t border-white/10 pt-2 text-xs text-white/50">
								{lineup?.bench.length
									? t('fixture.bench', { list: lineup.bench.map((p) => p.display_name + (p.reserve ? '' : t('fixture.onlyPosition', { n: (p.starter_slot ?? 0) + 1 }))).join(', ') })
									: t('score.subsNoBench')}
							</div>
						</div>
					{/each}
				</div>
				<div class="mt-5 flex justify-center">
					<button class="btn btn-ghost-dark" onclick={() => (subsDone = [...subsDone, subsKey!])}>{t('score.subsDone')}</button>
				</div>
			</div>
		{/if}

		<div class="grid gap-6 {m?.status === 'finished' && later.length ? 'lg:grid-cols-2' : ''}">
			{#if m?.status === 'finished'}
				{@const w = m.winner_side}
				<section>
					{@render sectionHead(t('score.lastGame'))}
					<div class="card-dark p-5">
						<div class="mb-3 text-xs text-white/60">{metaOf(m)}</div>
						<div class="grid grid-cols-[1fr_auto_1fr] items-center gap-3">
							{#each SIDES as side, i (side)}
								{#if i === 1}
									<span class="rounded-xl bg-white/10 px-3 py-1 font-display text-2xl font-extrabold tabular-nums ring-1 ring-white/10">{m.home.score} – {m.away.score}</span>
								{/if}
								<div class="flex min-w-0 flex-col {side === 'home' ? 'items-end text-right' : 'items-start text-left'} {w && w !== side ? 'opacity-50' : ''}">
									{@render players(m, side, 'sm')}
									{#if w === side}<span class="mt-1 flex items-center gap-1 text-xs font-bold text-gold-300">{@render trophy('h-3.5 w-3.5')}{t('score.winner')}</span>{/if}
								</div>
							{/each}
						</div>
						<div class="mt-4 flex flex-wrap justify-center gap-2 border-t border-white/10 pt-4">
							<button class="btn btn-ghost-dark btn-sm" disabled={sheetBusy} onclick={() => sheet(m)}>
								<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11m0 0-4-4m4 4 4-4M5 19h14" /></svg>
								{sheetBusy ? t('score.sheetBusy') : t('score.sheet')}
							</button>
							<button class="btn btn-ghost-dark btn-sm" {disabled} onclick={undo}>{t('score.undoLast')}</button>
							{#if session.canManage}<button class="btn btn-ghost-dark btn-sm" {disabled} onclick={clear}>{t('score.clear')}</button>{/if}
						</div>
					</div>
				</section>
			{/if}

			{#if later.length}
				<section>
					{@render sectionHead(t('score.later'))}
					<ol class="card-dark divide-y divide-white/10">
						{#each later as q (q.id)}
							<li class="flex items-center gap-3 px-4 py-3 text-sm">
								<span class="w-16 shrink-0 text-xs text-white/50">{q.team_match && q.rubber_number ? t('score.game', { n: q.rubber_number }) : ''}</span>
								<span class="flex min-w-0 flex-1 items-center justify-end gap-2 text-right">
									<span class="truncate font-semibold">{q.home.name}</span>
									<span class="h-2 w-2 shrink-0 rounded-full" style:background={colorOf(q, 'home')}></span>
								</span>
								<span class="text-xs font-bold text-white/40 uppercase">{t('common.vs')}</span>
								<span class="flex min-w-0 flex-1 items-center gap-2">
									<span class="h-2 w-2 shrink-0 rounded-full" style:background={colorOf(q, 'away')}></span>
									<span class="truncate font-semibold">{q.away.name}</span>
								</span>
							</li>
						{/each}
					</ol>
				</section>
			{/if}
		</div>
	{/if}
</div>
</div>

<style lang="postcss">
	@reference "../../../../app.css";

	/* The light pages' .card, in the dark */
	.card-dark {
		@apply rounded-2xl border border-white/10 bg-white/[0.04] shadow-[0_8px_24px_-12px_rgb(0_0_0/0.5)];
	}
	/* The light pages' .btn-ghost, in the dark */
	.btn-ghost-dark {
		@apply text-white/80 shadow-[inset_0_0_0_1.5px_rgb(255_255_255/0.2)] hover:text-gold-300 hover:shadow-[inset_0_0_0_1.5px_var(--color-gold-300)];
	}

	/* Dark panel lit by the side's colour, with a thin bar of it on top */
	.panel {
		background: linear-gradient(180deg, color-mix(in oklab, var(--c) 14%, #141414), #0d0d0d 70%);
		box-shadow:
			inset 0 4px 0 var(--c),
			inset 0 0 0 1px color-mix(in oklab, var(--c) 30%, transparent),
			0 20px 40px -20px rgb(0 0 0 / 0.6);
	}
	/* The next game: a touch of gold, nothing louder */
	.hero {
		border-color: color-mix(in oklab, var(--color-gold-300) 30%, transparent);
		background: linear-gradient(180deg, rgb(255 255 255 / 0.06), rgb(255 255 255 / 0.02));
	}
	/* Edge padding that stays clear of rounded corners and notches */
	.safe {
		padding: max(1rem, env(safe-area-inset-top)) max(1rem, env(safe-area-inset-right)) max(1rem, env(safe-area-inset-bottom)) max(1rem, env(safe-area-inset-left));
	}
	/* The score follows the screen: big on a tablet, still fits in landscape */
	.score-num {
		font-size: clamp(5rem, min(24vh, 18vw), 16rem);
	}
	.glow {
		background: radial-gradient(70% 60% at 50% 0%, color-mix(in oklab, var(--c) 28%, transparent), transparent);
	}
</style>
