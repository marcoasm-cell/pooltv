<!-- Live view of every table: what is playing, the score, what is up next -->
<script lang="ts">
	import { api } from '#lib/api.ts';
	import MatchLine from '#lib/components/MatchLine.svelte';
	import { errorMessage, roundLabel } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { live } from '#lib/live.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { Match, PoolTable, Side } from '#lib/types.ts';

	let tables = $state<PoolTable[] | null>(null);
	// The table whose card is asking who won, the one waiting on the server,
	// and the last error of each table
	let ending = $state<number | null>(null);
	let busy = $state<number | null>(null);
	let errors = $state<Record<number, string>>({});

	async function load() {
		tables = await api<PoolTable[]>('/pool_tables');
	}

	$effect(() => {
		load();
		return live.on((msg) => {
			if (msg.type !== 'table' || !tables) return;
			const i = tables.findIndex((t) => t.id === msg.table.id);
			if (i >= 0) tables[i] = { ...tables[i], ...msg.table };
			else load();
		}, load);
	});

	async function act(tableId: number, path: string, body: unknown = {}) {
		busy = tableId;
		errors[tableId] = '';
		try {
			await api(path, { body });
			ending = null;
			await load();
		} catch (e) {
			errors[tableId] = errorMessage(e);
		} finally {
			busy = null;
		}
	}

	const finishMatch = (tableId: number, m: Match, winner: Side) =>
		confirm(t('score.confirmConcede', { name: m[winner].name })) &&
		act(tableId, `/matches/${m.id}/finish`, { winner_side: winner });
	const endTournament = (tableId: number, m: Match) =>
		m.tournament &&
		confirm(t('dashboard.confirmEndTournament', { name: m.tournament.name })) &&
		act(tableId, `/tournaments/${m.tournament.id}/end_early`);
	const clearTable = (tableId: number) => act(tableId, `/pool_tables/${tableId}/clear`);
</script>

<header class="mb-8 flex flex-wrap items-end justify-between gap-3">
	<div>
		<p class="eyebrow mb-1">{t('dashboard.eyebrow')}</p>
		<h1 class="page-title">{t('dashboard.title')}</h1>
	</div>
</header>

{#if tables === null}
	<p class="text-gray-500">{t('common.loading')}</p>
{:else if tables.length === 0}
	<div class="card p-10 text-center">
		<p class="mb-4 text-lg font-semibold text-gray-700">{t('dashboard.noTables')}</p>
		{#if session.canManage}<a href="/tables" class="btn btn-primary">{t('dashboard.addTables')}</a>{/if}
	</div>
{:else}
	<div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
		{#each tables.filter((t) => t.active) as table (table.id)}
			{@const m = table.current_match}
			{@const disabled = busy === table.id}
			<article class="card flex flex-col overflow-hidden transition hover:shadow-md">
				<a href="/score/{table.id}" class="flex flex-1 flex-col" aria-label="{t('dashboard.score')} · {table.name}">
				<div class="m-1.5 mb-0">
					<div class="surface-dark flex items-center justify-between gap-3 rounded-xl px-4 py-3.5">
						<h2 class="truncate text-lg text-white">{table.name}</h2>
						{#if m?.status === 'live'}
							<span class="badge badge-live">{t('common.live')}</span>
						{:else}
							<span class="badge bg-white/10 text-white/70">{m?.status === 'finished' ? t('common.final') : t('common.free')}</span>
						{/if}
					</div>
				</div>
				<div class="flex flex-1 flex-col justify-center px-4 py-5">
					{#if m}
						<MatchLine match={m} />
						<p class="mt-3 text-center text-xs text-gray-500">
							{[m.name ?? m.tournament?.name, m.round_label?.key === 'friendly' ? null : roundLabel(m.round_label), m.game_type.name].filter(Boolean).join(' · ')}
						</p>
					{:else}
						<p class="text-center text-sm text-gray-400">{t('dashboard.tableFree')}</p>
					{/if}
				</div>
				</a>

				{#if m?.status === 'live' && ending === table.id}
					<!-- Who won? -->
					<div class="border-t border-gray-100 bg-gray-50 px-4 py-3">
						<p class="mb-2 text-xs font-semibold text-gray-600">{t('dashboard.whoWon')}</p>
						<div class="flex flex-wrap gap-2">
							{#each ['home', 'away'] as const as side (side)}
								<button class="btn btn-ghost btn-sm min-w-0 flex-1 truncate" {disabled} onclick={() => finishMatch(table.id, m, side)}>{m[side].name}</button>
							{/each}
						</div>
						<div class="mt-2 flex items-center justify-between gap-3">
							{#if session.canManage && m.tournament}
								<button class="link-danger" {disabled} onclick={() => endTournament(table.id, m)}>{t('dashboard.endTournament')}</button>
							{:else}<span></span>{/if}
							<button class="text-xs text-gray-500 hover:text-gray-800" onclick={() => (ending = null)}>{t('common.cancel')}</button>
						</div>
					</div>
				{/if}
				{#if errors[table.id]}<p class="alert-error mx-4 mb-3 text-xs">{errors[table.id]}</p>{/if}

				<div class="flex items-center gap-3 border-t border-gray-100 px-4 py-3">
					<p class="min-w-0 flex-1 truncate text-xs text-gray-500">
						{#if table.next_match}
							<span class="font-semibold text-gray-600">{t('common.upNext')}</span> · {table.next_match.home.name} {t('common.vs')} {table.next_match.away.name}
						{:else}
							{t('dashboard.nothingQueued')}
						{/if}
					</p>
					{#if m?.status === 'live' && ending !== table.id}
						<button class="btn btn-ghost btn-sm" {disabled} onclick={() => { ending = table.id; errors[table.id] = ''; }}>{t('dashboard.end')}</button>
					{:else if m?.status === 'finished' && session.canManage}
						<button class="btn btn-ghost btn-sm" {disabled} onclick={() => clearTable(table.id)}>{t('score.clear')}</button>
					{/if}
					<a href="/score/{table.id}" class="btn btn-dark btn-sm">{t('dashboard.score')}</a>
				</div>
			</article>
		{/each}
	</div>
{/if}
