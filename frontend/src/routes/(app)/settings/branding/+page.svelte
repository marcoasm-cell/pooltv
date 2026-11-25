<script lang="ts">
	import { api, photoUrl } from '#lib/api.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { accountSettings } from '../account.svelte.ts';
	import Sponsors from './Sponsors.svelte';

	const settings = accountSettings();
	const s = settings.state;
	const { run, saveOverlay } = settings;

	$effect(() => {
		settings.load();
	});

	const uploadClubLogo = (e: Event) => {
		const file = (e.currentTarget as HTMLInputElement).files?.[0];
		if (!file) return;
		const form = new FormData();
		form.append('logo', file);
		run(() => api('/account/logo', { method: 'PUT', body: form }));
	};
</script>

<header class="mb-8">
	<p class="eyebrow mb-1">{t('settings.title')}</p>
	<div class="flex items-center gap-3">
		<h1 class="page-title">{t('settings.branding')}</h1>
		{#if s.saved}<span class="badge bg-gold-100 text-gold-700">{t('settings.saved')}</span>{/if}
	</div>
</header>
{#if s.error}<p class="alert-error mb-4">{s.error}</p>{/if}

{#if s.account?.overlay_settings}
	{@const account = s.account}
	{@const o = s.account.overlay_settings}
	<section class="card p-6">
		<p class="mb-5 text-xs text-gray-500">{t('settings.brandingHelp')}</p>

		<div class="mb-6 flex flex-wrap items-center gap-4">
			<!-- Shown on the frame colour, as on air -->
			<div class="logo-preview h-16 w-56">
				{#if account.logo_url}
					<img src={photoUrl(account.logo_url)} alt={account.name} class="max-h-11 max-w-[200px] object-contain" />
				{:else}
					<span class="text-xs text-white/50">{t('settings.noLogo')}</span>
				{/if}
			</div>
			<div class="flex flex-col gap-2">
				<span class="text-sm font-medium">{t('settings.clubLogo')}</span>
				<div class="flex items-center gap-3">
					<label class="btn btn-ghost btn-sm cursor-pointer">
						{account.logo_url ? t('settings.replaceLogo') : t('settings.uploadLogo')}
						<input type="file" accept="image/png,image/jpeg,image/webp" class="hidden" onchange={uploadClubLogo} />
					</label>
					{#if account.logo_url}
						<button class="link-danger" onclick={() => run(() => api('/account/logo', { method: 'DELETE' }))}>{t('common.remove')}</button>
					{/if}
				</div>
			</div>
		</div>

		<div class="mb-6 grid gap-4 sm:grid-cols-3">
			<label class="flex items-center gap-2 text-sm sm:col-span-2">
				<input type="checkbox" checked={o.show_pool_tv_logo !== false}
					onchange={(e) => saveOverlay({ show_pool_tv_logo: e.currentTarget.checked })} />
				{t('settings.showPoolTv')}
			</label>
			<label class="lbl">{t('settings.sponsorSeconds')}
				<input class="field" type="number" min="3" value={o.sponsor_seconds}
					onchange={(e) => saveOverlay({ sponsor_seconds: Number(e.currentTarget.value) })} />
			</label>
		</div>

		<Sponsors />
	</section>
{/if}

<style>
	/* Logos previewed on the overlay frame's colour */
	.logo-preview {
		display: grid;
		place-items: center;
		flex: none;
		border-radius: 10px;
		background: rgb(13 15 14);
	}
</style>
