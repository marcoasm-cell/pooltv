<!-- A player's photo, or their initials -->
<script lang="ts">
	import { photoUrl } from '../api.ts';
	import type { Player } from '../types.ts';

	let { player, size = 'md' }: { player: Player; size?: 'sm' | 'md' } = $props();
	const initials = $derived(
		player.display_name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase()
	);
	const box = $derived(size === 'sm' ? 'h-7 w-7 text-[11px]' : 'h-11 w-11 text-sm');
</script>

{#if player.photo_url}
	<img src={photoUrl(player.photo_url)} alt="" loading="lazy" class="shrink-0 rounded-full bg-gray-200 object-cover ring-2 ring-white {box}" />
{:else}
	<span class="grid shrink-0 place-items-center rounded-full bg-gray-800 font-bold text-white ring-2 ring-white {box}">{initials}</span>
{/if}
