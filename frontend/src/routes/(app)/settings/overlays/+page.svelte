<script lang="ts">
	import { t } from '#lib/i18n/index.svelte.ts';
	import type { OverlayConfig } from '#lib/types.ts';
	import { accountSettings } from '../account.svelte.ts';

	const settings = accountSettings();
	const s = settings.state;
	const { saveOverlay } = settings;

	$effect(() => {
		settings.load();
	});
</script>

<header class="mb-8">
	<p class="eyebrow mb-1">{t('settings.title')}</p>
	<div class="flex items-center gap-3">
		<h1 class="page-title">{t('settings.overlays')}</h1>
		{#if s.saved}<span class="badge bg-gold-100 text-gold-700">{t('settings.saved')}</span>{/if}
	</div>
</header>
{#if s.error}<p class="alert-error mb-4">{s.error}</p>{/if}

{#if s.account?.overlay_settings}
	{@const o = s.account.overlay_settings}
	<section class="card p-6">
		<div class="grid gap-4 sm:grid-cols-3">
			<label class="lbl">{t('settings.idle')}
				<select class="field" value={o.idle_mode} onchange={(e) => saveOverlay({ idle_mode: e.currentTarget.value as OverlayConfig['idle_mode'] })}>
					<option value="hidden">{t('settings.idleHidden')}</option>
					<option value="waiting">{t('settings.idleWaiting')}</option>
				</select>
			</label>
			<label class="lbl">{t('settings.winnerBanner')}
				<input class="field" type="number" min="0" value={o.winner_banner_seconds}
					onchange={(e) => saveOverlay({ winner_banner_seconds: Number(e.currentTarget.value) })} />
			</label>
			<label class="lbl">{t('settings.allLayout')}
				<select class="field" value={o.all_tables_layout} onchange={(e) => saveOverlay({ all_tables_layout: e.currentTarget.value as OverlayConfig['all_tables_layout'] })}>
					<option value="split">{t('settings.layoutSplit')}</option>
					<option value="grid">{t('settings.layoutGrid')}</option>
					<option value="sidebar">{t('settings.layoutSidebar')}</option>
					<option value="ticker">{t('settings.layoutTicker')}</option>
				</select>
			</label>
		</div>
		<label class="mt-4 flex items-center gap-2 text-sm">
			<input type="checkbox" checked={o.show_qr !== false}
				onchange={(e) => saveOverlay({ show_qr: e.currentTarget.checked })} />
			{t('settings.showQr')}
		</label>
	</section>
{/if}
