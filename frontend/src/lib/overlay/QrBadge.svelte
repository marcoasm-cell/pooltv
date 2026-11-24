<!-- QR code on the overlays: viewers scan it to follow the score (or the tournament) on their phone -->
<script lang="ts">
	import { fade } from 'svelte/transition';
	import QrCode from '../components/QrCode.svelte';
	import { t } from '../i18n/index.svelte.ts';

	let { url }: { url: string } = $props();
</script>

<div class="qr" transition:fade={{ duration: 300 }}>
	<QrCode value={url} class="code" label={t('public.scan')} />
	<span>{t('public.scan')}</span>
</div>

<style>
	.qr {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 10px 10px 8px;
		border-radius: 14px;
		background: rgb(8 8 8 / 0.88);
		box-shadow: inset 0 0 0 1px rgb(255 255 255 / 0.08), 0 8px 24px rgb(0 0 0 / 0.35);
		color: rgb(255 255 255 / 0.75);
		font: 600 13px/1.1 'Inter', 'Segoe UI', system-ui, sans-serif;
		letter-spacing: 0.04em;
		text-transform: uppercase;
	}
	.qr :global(.code) {
		display: block;
		width: 128px;
		height: 128px;
		border-radius: 6px;
	}
	.qr span {
		max-width: 128px;
		text-align: center;
	}
	/* Narrow browser sources, e.g. two overlays side by side at 960x1080 */
	@media (max-width: 1200px) {
		.qr :global(.code) {
			width: 96px;
			height: 96px;
		}
		.qr span {
			max-width: 96px;
			font-size: 11px;
		}
	}
</style>
