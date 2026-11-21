<!-- Compact one-line match: names and score -->
<script lang="ts">
	import type { Match } from '../types.ts';

	let { match }: { match: Match } = $props();
</script>

<div class="flex items-center gap-3">
	<span class="flex-1 truncate text-right font-semibold" class:text-gold-600={match.winner_side === 'home'}>
		{#if match.winner_side === 'home'}<span class="text-gold-500">★</span>{/if}
		{match.home.name}
	</span>
	<span class="flex items-center overflow-hidden rounded-lg bg-gray-950 font-display text-xl font-extrabold tabular-nums">
		<span class="px-3 py-1 text-white">{match.home.score}</span>
		<span class="h-4 w-px bg-white/20"></span>
		<span class="px-3 py-1 text-white">{match.away.score}</span>
	</span>
	<span class="flex-1 truncate font-semibold" class:text-gold-600={match.winner_side === 'away'}>
		{match.away.name}
		{#if match.winner_side === 'away'}<span class="text-gold-500">★</span>{/if}
	</span>
</div>
