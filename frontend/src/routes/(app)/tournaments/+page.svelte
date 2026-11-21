<script lang="ts">
	import { goto } from '$app/navigation';
	import { api } from '#lib/api.ts';
	import { errorMessage, FORMATS, formatLabel } from '#lib/format.ts';
	import { t, tk, tn } from '#lib/i18n/index.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { GameType, PoolTable, Tournament } from '#lib/types.ts';

	type Kind = Tournament['kind'];
	type Format = Tournament['format'];

	let tournaments = $state<Tournament[]>([]);
	let gameTypes = $state<GameType[]>([]);
	let tables = $state<PoolTable[]>([]);
	let creating = $state(false);
	let saving = $state(false);
	let error = $state('');
	let form = $state({
		name: '',
		kind: 'individual' as Kind,
		format: 'single_elimination' as Format,
		game_type_id: 0,
		target: 5,
		grand_final_reset: true,
		team_match_format: ['singles', 'singles', 'doubles', 'singles', 'singles'] as ('singles' | 'doubles')[],
		team_win_condition: 'rubbers' as Tournament['team_win_condition'],
		team_target: 3 as number | null,
		// Tables the games are dealt to, in the order picked
		pool_table_ids: [] as number[]
	});

	const KINDS: { value: Kind; label: string }[] = $derived([
		{ value: 'individual', label: t('tournaments.individual') },
		{ value: 'team', label: t('tournaments.teams') }
	]);
	const gameType = $derived(gameTypes.find((g) => g.id === form.game_type_id));

	$effect(() => {
		api<Tournament[]>('/tournaments').then((tour) => (tournaments = tour));
		api<GameType[]>('/game_types').then((g) => {
			gameTypes = g;
			const def = g.find((x) => x.key === 'pt_pool') ?? g[0];
			if (def) pickGame(def.id);
		});
		api<PoolTable[]>('/pool_tables').then((x) => {
			tables = x.filter((tb) => tb.active);
			form.pool_table_ids = tables.map((tb) => tb.id);
		});
	});

	function pickGame(id: number) {
		form.game_type_id = id;
		form.target = gameTypes.find((g) => g.id === id)?.default_target ?? form.target;
	}

	function toggleTable(id: number) {
		const i = form.pool_table_ids.indexOf(id);
		if (i >= 0) form.pool_table_ids.splice(i, 1);
		else form.pool_table_ids.push(id);
	}
	const allTables = $derived(tables.length > 0 && form.pool_table_ids.length === tables.length);
	const toggleAll = () => (form.pool_table_ids = allTables ? [] : tables.map((x) => x.id));

	async function create(e: SubmitEvent) {
		e.preventDefault();
		error = '';
		saving = true;
		try {
			const body = form.kind === 'team' ? form : { ...form, team_match_format: [], team_target: null };
			const tour = await api<Tournament>('/tournaments', { body });
			await goto(`/tournaments/${tour.id}`);
		} catch (err) {
			error = errorMessage(err);
		} finally {
			saving = false;
		}
	}

	const statusColor = { draft: 'bg-gray-100 text-gray-600', running: 'bg-red-50 text-red-600', finished: 'bg-gold-100 text-gold-700' };
</script>

{#snippet stepHead(n: number, title: string, hint = '')}
	<div class="mb-3 flex items-center gap-3">
		<span class="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-gold-100 font-condensed text-sm font-bold text-gold-700 ring-1 ring-gold-200">{n}</span>
		<h3 class="font-condensed! text-[15px] font-bold! tracking-[0.16em]! text-gray-900 uppercase">{title}</h3>
		{#if hint}<span class="text-xs text-gray-500">{hint}</span>{/if}
		<span class="h-px flex-1 bg-gray-200"></span>
	</div>
{/snippet}

{#snippet formatIcon(format: Format | Kind)}
	<svg viewBox="0 0 24 24" class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
		{#if format === 'individual'}
			<circle cx="12" cy="8" r="3.5" /><path d="M5 20c0-3.9 3.1-6.5 7-6.5s7 2.6 7 6.5" />
		{:else if format === 'team'}
			<circle cx="8.5" cy="8.5" r="3" /><path d="M2.5 19.5c0-3.3 2.7-5.5 6-5.5s6 2.2 6 5.5" />
			<circle cx="16.5" cy="7" r="2.6" /><path d="M15.2 12.7c.4-.1.9-.2 1.3-.2 2.9 0 5 2 5 5" />
		{:else if format === 'single_elimination'}
			<path d="M3 5h5v4h5M3 15h5v-4M13 9v6M13 12h8M3 19h5v-4" />
		{:else if format === 'double_elimination'}
			<path d="M3 4h4v3h4M3 10h4V7M11 7v3h4" /><path d="M3 14h4v3h4M3 20h4v-3M11 17v-3h4M15 10v4M15 12h6" />
		{:else if format === 'round_robin'}
			<circle cx="12" cy="4.5" r="2" /><circle cx="19.5" cy="12" r="2" /><circle cx="12" cy="19.5" r="2" /><circle cx="4.5" cy="12" r="2" />
			<path d="M13.4 5.9l4.7 4.7M18.1 13.4l-4.7 4.7M10.6 18.1l-4.7-4.7M5.9 10.6l4.7-4.7M12 6.5v11M6.5 12h11" />
		{:else}
			<path d="M7 4h10v4a5 5 0 0 1-10 0V4Z" /><path d="M12 13v3.5M8.5 20h7M9.5 20l.8-3.5h3.4l.8 3.5" />
		{/if}
	</svg>
{/snippet}

<header class="mb-8 flex flex-wrap items-end justify-between gap-3">
	<div>
		<p class="eyebrow mb-1">{t('tournaments.eyebrow')}</p>
		<h1 class="page-title">{t('tournaments.title')}</h1>
	</div>
	{#if session.canManage}
		<button class="btn {creating ? 'btn-ghost' : 'btn-primary'}" onclick={() => (creating = !creating)}>
			{#if creating}{t('common.cancel')}{:else}<span class="btn-icon">+</span>{t('tournaments.new')}{/if}
		</button>
	{/if}
</header>

{#if creating}
	<form class="card mb-8 overflow-hidden" onsubmit={create}>
		<div class="divide-y divide-gray-100">
			<!-- 1. Name and who plays -->
			<section class="p-6">
				{@render stepHead(1, t('tournaments.step.basics'))}
				<label class="lbl">{t('common.name')}
					<input class="field" bind:value={form.name} required maxlength="80" placeholder={t('tournaments.namePh')} />
				</label>
				<div class="mt-4 grid grid-cols-2 gap-3">
					{#each KINDS as k (k.value)}
						{@const on = form.kind === k.value}
						<button type="button" aria-pressed={on} onclick={() => (form.kind = k.value)} class="opt" class:opt-on={on}>
							<span class="opt-icon">{@render formatIcon(k.value)}</span>
							<span class="opt-label">{k.label}</span>
						</button>
					{/each}
				</div>
			</section>

			<!-- 2. Format -->
			<section class="p-6">
				{@render stepHead(2, t('tournaments.step.format'))}
				<div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
					{#each FORMATS as f (f)}
						{@const on = form.format === f}
						<button type="button" aria-pressed={on} onclick={() => (form.format = f)} class="opt" class:opt-on={on}>
							<span class="opt-icon">{@render formatIcon(f)}</span>
							<span class="min-w-0">
								<span class="opt-label">{formatLabel(f)}</span>
								<span class="opt-hint">{tk(`tournaments.formatHint.${f}`)}</span>
							</span>
						</button>
					{/each}
				</div>
				{#if form.format === 'double_elimination'}
					<label class="mt-3 inline-flex items-center gap-2 text-sm text-gray-700" title={t('tournaments.gfReset')}>
						<input type="checkbox" bind:checked={form.grand_final_reset} />
						{t('tournaments.gfResetShort')}
					</label>
				{/if}
			</section>

			<!-- 3. Game and race -->
			<section class="p-6">
				{@render stepHead(3, t('tournaments.step.rules'))}
				<div class="grid gap-6 sm:grid-cols-[1fr_auto]">
					<div>
						<span class="lbl">{t('common.game')}</span>
						<div class="mt-2 flex flex-wrap gap-2">
							{#each gameTypes as g (g.id)}
								{@const on = form.game_type_id === g.id}
								<button type="button" aria-pressed={on} onclick={() => pickGame(g.id)} class="pill" class:pill-on={on}>{g.name}</button>
							{/each}
						</div>
					</div>
					<div>
						<span class="lbl">{gameType?.scoring_mode === 'points' ? t('common.pointsToWin') : t('tournaments.raceRacks')}</span>
						<div class="mt-2 inline-flex items-center gap-1 rounded-full border border-gray-200 bg-gray-50 p-1">
							<button type="button" class="step" disabled={form.target <= 1} onclick={() => (form.target = Math.max(1, form.target - 1))} aria-label={t('common.less')}>−</button>
							<input class="number w-14 bg-transparent text-center font-display text-xl font-extrabold tabular-nums outline-none" type="number" min="1" required bind:value={form.target} />
							<button type="button" class="step" onclick={() => (form.target += 1)} aria-label={t('common.more')}>+</button>
						</div>
					</div>
				</div>
			</section>

			<!-- 4. Team match (team tournaments only) -->
			{#if form.kind === 'team'}
				<section class="p-6">
					{@render stepHead(4, t('tournaments.step.teamMatch'))}
					<div class="mb-5 flex flex-wrap gap-2">
						{#each form.team_match_format as kind, i (i)}
							<span class="flex items-center gap-1 rounded-full bg-white py-1 pr-1 pl-3 text-sm ring-1 ring-gray-200">
								<span class="font-semibold text-gray-400">{i + 1}</span>
								<select class="bg-transparent outline-none" bind:value={form.team_match_format[i]}>
									<option value="singles">{t('kind.singles')}</option>
									<option value="doubles">{t('kind.doubles')}</option>
								</select>
								<button type="button" class="grid h-6 w-6 place-items-center rounded-full text-gray-400 transition hover:bg-red-50 hover:text-red-600 disabled:opacity-30"
									disabled={form.team_match_format.length <= 1} onclick={() => form.team_match_format.splice(i, 1)} aria-label={t('tournaments.removeRubber')}>×</button>
							</span>
						{/each}
						<button type="button" class="rounded-full border border-dashed border-gray-300 px-3 py-1 text-sm text-gray-600 transition hover:border-gold-400 hover:text-gold-600" onclick={() => form.team_match_format.push('singles')}>{t('tournaments.addRubber')}</button>
					</div>
					<div class="grid gap-4 sm:grid-cols-2">
						<label class="lbl">{t('tournaments.winner')}
							<select class="field" bind:value={form.team_win_condition}>
								<option value="rubbers">{t('tournaments.mostRubbers')}</option>
								<option value="racks">{t('tournaments.mostRacks')}</option>
							</select>
						</label>
						{#if form.team_win_condition === 'rubbers'}
							<label class="lbl">{t('tournaments.stopAt')}
								<input class="field" type="number" min="1" max={form.team_match_format.length} bind:value={form.team_target} placeholder={t('tournaments.playAll')} />
							</label>
						{/if}
					</div>
				</section>
			{/if}

			<!-- 5. Tables: games are dealt to them automatically -->
			<section class="p-6">
				<div class="flex items-start gap-3">
					<div class="flex-1">{@render stepHead(form.kind === 'team' ? 5 : 4, t('tournaments.step.tables'), t('tournaments.tablesAuto'))}</div>
					{#if tables.length > 1}
						<button type="button" class="link-quiet" onclick={toggleAll}>{allTables ? t('tournaments.noneTables') : t('tournaments.allTables')}</button>
					{/if}
				</div>
				<div class="grid grid-cols-2 gap-2.5 sm:grid-cols-3 lg:grid-cols-4">
					{#each tables as x (x.id)}
						{@const n = form.pool_table_ids.indexOf(x.id)}
						{@const on = n >= 0}
						{@const busy = x.current_match?.status === 'live'}
						<button type="button" aria-pressed={on} onclick={() => toggleTable(x.id)}
							class="relative flex items-center gap-3 rounded-xl border px-3 py-3 text-left transition {on ? 'border-gold-400 bg-gold-100/40 ring-4 ring-gold-300/20' : 'border-gray-200 bg-white hover:border-gray-300 hover:shadow-sm'}">
							<!-- A tiny table seen from above -->
							<span class="relative h-6 w-10 shrink-0 rounded-[6px] border-[3px] {on ? 'border-gold-400 bg-gold-100' : 'border-gray-300 bg-gray-100'}">
								{#if busy}<span class="absolute -top-1 -right-1 h-2.5 w-2.5 rounded-full bg-red-500 ring-2 ring-white"></span>{/if}
							</span>
							<span class="min-w-0">
								<span class="block truncate font-semibold">{x.name}</span>
								<span class="block text-xs {busy ? 'text-red-600' : 'text-gray-500'}">{busy ? t('newMatch.playing') : t('common.free')}</span>
							</span>
							{#if on}
								<span class="absolute top-2 right-2 grid h-5 w-5 place-items-center rounded-full bg-gold-400 text-[11px] font-black text-white">✓</span>
							{/if}
						</button>
					{:else}
						<p class="col-span-full rounded-xl border-2 border-dashed border-gray-200 px-4 py-5 text-center text-sm text-gray-500">
							{t('newMatch.noTables')} <a class="font-semibold underline decoration-gold-400 underline-offset-2" href="/tables">{t('nav.tables')}</a>.
						</p>
					{/each}
				</div>
			</section>
		</div>

		<footer class="flex flex-wrap items-center justify-end gap-3 border-t border-gray-100 bg-gray-50 px-6 py-4">
			{#if error}<p class="alert-error mr-auto">{error}</p>{/if}
			<button type="button" class="btn btn-ghost" onclick={() => (creating = false)}>{t('common.cancel')}</button>
			<button class="btn btn-primary" disabled={saving || !form.name.trim()}>{t('tournaments.create')}</button>
		</footer>
	</form>
{/if}

<div class="card divide-y divide-gray-100 overflow-hidden">
	{#each tournaments as tour (tour.id)}
		<a href="/tournaments/{tour.id}" class="group flex items-center gap-4 px-5 py-4 transition hover:bg-gray-50">
			<span class="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-black text-lg text-gold-300">🏆</span>
			<div class="min-w-0 flex-1">
				<div class="truncate font-semibold text-gray-900">{tour.name}</div>
				<div class="truncate text-sm text-gray-500">
					{tour.game_type.name} · {formatLabel(tour.format)} · {tour.kind === 'team' ? t('tournaments.teams') : t('tournaments.individual')} · {tn('tournaments.entries', tour.entries_count)}
				</div>
			</div>
			<span class="badge {statusColor[tour.status]}">{t(`status.${tour.status}`)}</span>
			<span class="text-gray-300 transition group-hover:translate-x-0.5 group-hover:text-gray-500">→</span>
		</a>
	{:else}
		<p class="p-8 text-center text-sm text-gray-500">{t('tournaments.none')}</p>
	{/each}
</div>

<style lang="postcss">
	@reference "../../../app.css";

	/* Selectable cards for who plays and the format */
	.opt {
		@apply flex items-center gap-3 rounded-xl border border-gray-200 bg-white p-3 text-left transition hover:border-gray-300 hover:shadow-sm;
	}
	.opt-on {
		@apply border-gold-400 bg-gold-100/40 ring-4 ring-gold-300/20 hover:border-gold-400 hover:shadow-none;
	}
	.opt-icon {
		@apply grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-gray-100 text-gray-600 transition;
	}
	.opt-on .opt-icon {
		@apply bg-gold-200/70 text-gray-900;
	}
	.opt-label {
		@apply block font-display leading-tight font-bold text-gray-900;
	}
	.opt-hint {
		@apply mt-0.5 block text-xs text-gray-500;
	}
	.link-quiet {
		@apply pt-1 text-xs font-semibold text-gray-500 underline decoration-gray-300 underline-offset-2 transition hover:text-gray-900 hover:decoration-gold-400;
	}
	.pill {
		@apply rounded-xl border border-gray-200 bg-white px-4 py-2 text-sm font-semibold text-gray-700 transition hover:border-gray-300 hover:shadow-sm;
	}
	.pill-on {
		@apply border-gold-400 bg-gold-100/40 text-gray-900 ring-4 ring-gold-300/20;
	}
	.step {
		@apply grid h-9 w-9 place-items-center rounded-full bg-white text-lg font-bold text-gray-800 shadow-sm ring-1 ring-gray-200 transition hover:bg-gold-100 hover:ring-gold-400 active:scale-95 disabled:opacity-30 disabled:hover:bg-white disabled:hover:ring-gray-200;
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
</style>
