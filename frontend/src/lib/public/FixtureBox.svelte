<!-- A fixture in the public bracket: both entries and the score; opens the match being played -->
<script lang="ts">
	import { t } from '../i18n/index.svelte.ts';
	import type { Fixture } from '../types.ts';

	let { fixture }: { fixture: Fixture } = $props();

	const started = $derived(fixture.status === 'live' || fixture.status === 'finished');
	// The match to open: the one on now, else the last one played
	const target = $derived.by(() => {
		const ms = fixture.matches ?? [];
		return ms.find((m) => m.status === 'live') ?? ms.findLast((m) => m.status === 'finished') ?? (ms.length === 1 ? ms[0] : null);
	});
	const rows = $derived([
		{ side: 'home', entry: fixture.home, bye: fixture.home_bye, score: fixture.home_score },
		{ side: 'away', entry: fixture.away, bye: fixture.away_bye, score: fixture.away_score }
	] as const);
</script>

<svelte:element this={target ? 'a' : 'div'} href={target ? `/m/${target.public_token}` : undefined}
	class="box block w-full overflow-hidden rounded-xl border bg-white text-sm transition
		{fixture.status === 'live' ? 'border-red-300 shadow-[0_0_0_3px_rgb(192_57_43/0.1)]' : 'border-gray-200'}
		{target ? 'hover:border-gray-400' : ''}"
	class:opacity-50={fixture.status === 'void'}>
	{#each rows as r, i (r.side)}
		{@const won = !!r.entry && r.entry.id === fixture.winner_entry_id}
		{@const lost = !!fixture.winner_entry_id && !won}
		<div class="flex h-8 items-center gap-2 px-3 {i ? 'border-t border-gray-100' : ''}">
			<span class="min-w-0 flex-1 truncate {won ? 'font-bold text-gray-950' : lost ? 'text-gray-400' : 'text-gray-800'}"
				class:italic={!r.entry} class:text-gray-400={!r.entry}>
				{r.entry?.display_name ?? (r.bye ? t('fixture.bye') : t('fixture.tbd'))}
			</span>
			{#if started && !fixture.home_bye && !fixture.away_bye}
				<span class="grid h-6 min-w-6 place-items-center rounded-md px-1.5 font-display text-[13px] font-extrabold tabular-nums
					{won ? 'bg-gray-950 text-gold-300' : 'bg-gray-100 text-gray-700'}">{r.score}</span>
			{/if}
		</div>
	{/each}
</svelte:element>
