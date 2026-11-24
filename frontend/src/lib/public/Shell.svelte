<!--
  Frame of the public pages (reached by the QR code, no sign-in): the club in a dark band,
  the connection state, and the page below on the light surface of the app.
-->
<script lang="ts">
	import type { Snippet } from 'svelte';
	import { photoUrl } from '../api.ts';
	import type { LiveStatus } from '../cable.ts';
	import Brand from '../components/Brand.svelte';
	import Credit from '../components/Credit.svelte';
	import LangSwitch from '../components/LangSwitch.svelte';
	import { t } from '../i18n/index.svelte.ts';
	import type { Branding } from '../types.ts';

	let { branding, status, children }: { branding: Branding | null; status: LiveStatus; children: Snippet } = $props();
</script>

<div class="flex min-h-dvh flex-col">
	<header class="surface-dark text-white">
		<div class="mx-auto flex max-w-5xl items-center gap-3 px-4 py-3">
			<a href="https://pooltv.me" class="shrink-0" aria-label="Pool TV"><Brand /></a>
			{#if branding?.logo_url}
				<span class="h-7 w-px bg-white/15"></span>
				<img src={photoUrl(branding.logo_url)} alt={branding.name} class="h-9 max-w-36 object-contain" />
			{/if}
			<span class="min-w-0 flex-1 truncate font-condensed text-lg font-semibold tracking-[0.06em] text-white/70 uppercase">{branding?.name ?? ''}</span>
			{#if status !== 'connected'}
				<span class="hidden text-xs text-white/50 sm:inline">{t('public.reconnecting')}</span>
			{/if}
			<span class="h-2 w-2 shrink-0 rounded-full {status === 'connected' ? 'bg-gold-300' : 'animate-pulse bg-white/30'}"
				title={status === 'connected' ? t('common.live') : t('public.reconnecting')}></span>
			<LangSwitch />
		</div>
	</header>

	<main class="mx-auto w-full max-w-5xl flex-1 px-4 py-6 sm:py-8">
		{@render children()}
	</main>

	<footer class="mx-auto w-full max-w-5xl px-4 pb-6">
		<Credit />
	</footer>
</div>
