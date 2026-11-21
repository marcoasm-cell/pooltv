<!-- PT / EN toggle; the choice is saved on this device -->
<script lang="ts">
	import { i18n, LOCALES, t } from '../i18n/index.svelte.ts';

	let { tone = 'dark' }: { tone?: 'dark' | 'light' } = $props();
</script>

<div class="inline-flex overflow-hidden rounded-full text-xs font-bold tracking-wider ring-1 {tone === 'dark' ? 'ring-white/20' : 'ring-gray-300'}"
	role="group" aria-label={t('lang.label')}>
	{#each LOCALES as locale (locale)}
		{@const on = i18n.locale === locale}
		<button type="button" class="px-2.5 py-1 transition
			{on ? 'bg-gold-300 text-black' : tone === 'dark' ? 'text-white/60 hover:text-gold-300' : 'text-gray-500 hover:text-gray-900'}"
			aria-pressed={on} onclick={() => i18n.set(locale)}>
			{t(`lang.${locale}`)}
		</button>
	{/each}
</div>
