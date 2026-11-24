<script lang="ts">
	import { api, photoUrl } from '#lib/api.ts';
	import { errorMessage } from '#lib/format.ts';
	import { t, tk } from '#lib/i18n/index.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { Account, GameType, OverlayConfig, User } from '#lib/types.ts';
	import Sponsors from './Sponsors.svelte';

	let account = $state<Account | null>(null);
	let users = $state<User[]>([]);
	let gameTypes = $state<GameType[]>([]);
	let error = $state('');
	let saved = $state(false);
	let newUser = $state({ name: '', email: '', password: '', role: 'scorer' as User['role'] });
	let newGame = $state({ key: '', name: '', scoring_mode: 'racks', default_target: 5, break_rule: 'alternate' });

	async function load() {
		[account, users, gameTypes] = await Promise.all([
			api<Account>('/account'),
			api<User[]>('/users'),
			api<GameType[]>('/game_types')
		]);
	}
	$effect(() => {
		load();
	});

	async function run(fn: () => Promise<unknown>) {
		error = '';
		try {
			await fn();
			await load();
		} catch (e) {
			error = errorMessage(e);
		}
	}

	async function saveOverlay(patch: Partial<OverlayConfig>) {
		await run(() => api('/account', { method: 'PATCH', body: { overlay_settings: patch } }));
		saved = true;
		setTimeout(() => (saved = false), 1200);
	}
	/** Multipart body with the picked file as "logo" plus other fields */
	function logoForm(file: File, fields: Record<string, string> = {}) {
		const form = new FormData();
		form.append('logo', file);
		for (const [k, v] of Object.entries(fields)) form.append(k, v);
		return form;
	}
	const fileOf = (e: Event) => (e.currentTarget as HTMLInputElement).files?.[0] ?? null;

	const uploadClubLogo = (e: Event) => {
		const file = fileOf(e);
		if (file) run(() => api('/account/logo', { method: 'PUT', body: logoForm(file) }));
	};
	const addUser = (e: SubmitEvent) => {
		e.preventDefault();
		run(async () => {
			await api('/users', { body: newUser });
			newUser = { name: '', email: '', password: '', role: 'scorer' };
		});
	};
	const addGame = (e: SubmitEvent) => {
		e.preventDefault();
		run(async () => {
			await api('/game_types', { body: newGame });
			newGame = { key: '', name: '', scoring_mode: 'racks', default_target: 5, break_rule: 'alternate' };
		});
	};
</script>

<header class="mb-8">
	<p class="eyebrow mb-1">{t('settings.eyebrow')}</p>
	<h1 class="page-title">{t('settings.title')}</h1>
</header>
{#if error}<p class="alert-error mb-4">{error}</p>{/if}

{#if account?.overlay_settings}
	{@const o = account.overlay_settings}
	<section class="card mb-6 p-6">
		<div class="mb-4 flex items-center gap-2">
			<h2 class="text-lg">{t('settings.overlays')}</h2>
			{#if saved}<span class="badge bg-gold-100 text-gold-700">{t('settings.saved')}</span>{/if}
		</div>
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

	<section class="card mb-6 p-6">
		<h2 class="mb-1 text-lg">{t('settings.branding')}</h2>
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

<section class="card mb-6 p-6">
	<h2 class="mb-1 text-lg">{t('settings.users')}</h2>
	<p class="mb-4 text-xs text-gray-500">{t('settings.usersHelp')}</p>
	<ul class="mb-4 divide-y divide-gray-100 text-sm">
		{#each users as u (u.id)}
			<li class="flex items-center gap-3 py-2.5">
				<span class="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-black text-xs font-bold text-gold-300">{u.name.trim().charAt(0).toUpperCase()}</span>
				<span class="min-w-0 flex-1 truncate"><span class="font-medium">{u.name}</span> <span class="text-gray-500">{u.email}</span></span>
				{#if u.admin}<span class="badge bg-gold-100 text-gold-700">{t('role.admin')}</span>{/if}
				<span class="badge bg-gray-100 text-gray-600">{t(`role.${u.role}`)}</span>
				{#if u.id !== session.user?.id && (!u.admin || session.isAdmin)}
					<button class="link-danger" onclick={() => confirm(t('common.confirmRemove', { name: u.name })) && run(() => api(`/users/${u.id}`, { method: 'DELETE' }))}>{t('common.remove')}</button>
				{/if}
			</li>
		{/each}
	</ul>
	<form class="flex flex-wrap gap-2 rounded-xl bg-gray-50 p-3 ring-1 ring-gray-200" onsubmit={addUser}>
		<input class="field flex-1" placeholder={t('common.name')} bind:value={newUser.name} required />
		<input class="field flex-1" type="email" placeholder={t('common.email')} bind:value={newUser.email} required />
		<input class="field flex-1" type="password" placeholder={t('common.password')} bind:value={newUser.password} required minlength="6" />
		<select class="field w-32" bind:value={newUser.role}>
			<option value="scorer">{t('roleOption.scorer')}</option>
			<option value="owner">{t('roleOption.owner')}</option>
		</select>
		<button class="btn btn-primary">{t('settings.addUser')}</button>
	</form>
</section>

<section class="card p-6">
	<h2 class="mb-4 text-lg">{t('settings.gameTypes')}</h2>
	<div class="mb-4 overflow-x-auto">
		<table class="data-table">
			<thead><tr><th>{t('common.name')}</th><th>{t('settings.col.scoring')}</th><th>{t('settings.col.default')}</th><th>{t('settings.col.break')}</th><th></th></tr></thead>
			<tbody>
				{#each gameTypes as g (g.id)}
					<tr>
						<td class="font-medium">{g.name}</td><td>{tk(`scoring.${g.scoring_mode}`)}</td><td class="tabular-nums">{g.default_target}</td><td>{tk(`break.${g.break_rule}`)}</td>
						<td class="text-right">
							{#if g.built_in}<span class="badge bg-gray-100 text-gray-500">{t('settings.builtIn')}</span>
							{:else}<button class="link-danger" onclick={() => run(() => api(`/game_types/${g.id}`, { method: 'DELETE' }))}>{t('common.remove')}</button>{/if}
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
	<form class="flex flex-wrap gap-2 rounded-xl bg-gray-50 p-3 ring-1 ring-gray-200" onsubmit={addGame}>
		<input class="field flex-1" placeholder={t('settings.gameNamePh')} bind:value={newGame.name} required
			oninput={() => (newGame.key = newGame.name.toLowerCase().replace(/[^a-z0-9]+/g, '_'))} />
		<select class="field w-28" bind:value={newGame.scoring_mode}><option value="racks">{t('scoring.racks')}</option><option value="points">{t('scoring.points')}</option></select>
		<input class="field w-20" type="number" min="1" bind:value={newGame.default_target} title={t('settings.defaultTitle')} />
		<select class="field w-36" bind:value={newGame.break_rule}>
			<option value="alternate">{t('break.alternate')}</option><option value="winner">{t('break.winner')}</option><option value="loser">{t('break.loser')}</option>
		</select>
		<button class="btn btn-primary">{t('settings.addGame')}</button>
	</form>
</section>

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
