<!-- One match in a list of a public page: names, score, and where/when; opens the match page -->
<script lang="ts">
	import { t } from '../i18n/index.svelte.ts';
	import type { Match, PublicTable } from '../types.ts';

	let { match, tables = [], caption = '' }: { match: Match; tables?: PublicTable[]; caption?: string } = $props();
	const table = $derived(tables.find((x) => x.id === match.pool_table_id)?.name);
	const started = $derived(match.status !== 'scheduled');
</script>

<a href="/m/{match.public_token}" class="block px-4 py-3 transition hover:bg-gray-50">
	{#if caption || table || match.status === 'live'}
		<div class="mb-1.5 flex items-center gap-2 text-xs text-gray-500">
			{#if match.status === 'live'}<span class="badge badge-live px-1.5! py-0! text-[10px]!">{t('common.live')}</span>{/if}
			<span class="truncate">{[caption, table].filter(Boolean).join(' · ')}</span>
		</div>
	{/if}
	<div class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-3">
		<span class="truncate text-right font-semibold" class:text-gray-400={match.winner_side === 'away'}>{match.home.name}</span>
		{#if started}
			<span class="rounded-md bg-gray-950 px-2 py-0.5 font-display text-base font-extrabold text-white tabular-nums">{match.home.score}–{match.away.score}</span>
		{:else}
			<span class="px-2 text-xs font-bold text-gray-400 uppercase">{t('common.vs')}</span>
		{/if}
		<span class="truncate font-semibold" class:text-gray-400={match.winner_side === 'home'}>{match.away.name}</span>
	</div>
</a>
