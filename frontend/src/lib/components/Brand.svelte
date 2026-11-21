<!-- Logo: the gold Pool TV badge (static/logo.png) -->
<script lang="ts">
	let { size = 'md' }: { size?: 'md' | 'lg' } = $props();
</script>

<img src="/logo.png" alt="Pool TV" draggable="false"
	class="inline-block shrink-0 select-none {size === 'lg' ? 'h-28 w-28' : 'h-12 w-12'}" />
