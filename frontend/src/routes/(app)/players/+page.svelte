<script lang="ts">
	import { api, photoUrl } from '#lib/api.ts';
	import { errorMessage } from '#lib/format.ts';
	import { t, tn } from '#lib/i18n/index.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { Player } from '#lib/types.ts';

	let players = $state<Player[]>([]);
	let form = $state({ name: '', nickname: '' });
	let q = $state('');
	let error = $state('');

	const filtered = $derived(players.filter((p) => `${p.name} ${p.nickname ?? ''}`.toLowerCase().includes(q.toLowerCase())));

	async function load() {
		players = await api<Player[]>('/players');
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

	const add = (e: SubmitEvent) => {
		e.preventDefault();
		run(async () => {
			await api('/players', { body: form });
			form = { name: '', nickname: '' };
		});
	};
	const save = (p: Player, field: 'name' | 'nickname', value: string) =>
		run(() => api(`/players/${p.id}`, { method: 'PATCH', body: { [field]: value } }));
	const remove = (p: Player) => confirm(t('common.confirmRemove', { name: p.name })) && run(() => api(`/players/${p.id}`, { method: 'DELETE' }));
</script>

<header class="mb-8 flex flex-wrap items-end gap-3">
	<div class="flex-1">
		<p class="eyebrow mb-1">{t('players.eyebrow')}</p>
		<h1 class="page-title">{t('players.title')}</h1>
	</div>
	{#if session.canManage}<a href="/fpb" class="btn btn-ghost btn-sm">{t('fpb.link')}</a>{/if}
</header>
{#if error}<p class="alert-error mb-4">{error}</p>{/if}

{#if session.canManage}
	<form class="card mb-5 flex flex-wrap gap-2 p-3" onsubmit={add}>
		<input class="field flex-1" placeholder={t('common.name')} bind:value={form.name} required />
		<input class="field flex-1" placeholder={t('players.nicknamePh')} bind:value={form.nickname} />
		<button class="btn btn-primary">{t('players.add')}</button>
	</form>
{/if}

<div class="card overflow-hidden">
	<div class="flex items-center gap-3 border-b border-gray-200 bg-gray-50/70 px-4 py-3">
		<input class="field max-w-xs py-1.5" placeholder={t('players.search')} bind:value={q} />
		<span class="ml-auto text-xs text-gray-500">{tn('players.count', filtered.length)}</span>
	</div>
	<div class="divide-y divide-gray-200">
		{#each filtered as p (p.id)}
			<div class="flex items-center gap-3 px-4 py-2 transition hover:bg-gray-50">
				{#if p.photo_url}
					<img src={photoUrl(p.photo_url)} alt="" loading="lazy" class="h-8 w-8 shrink-0 rounded-full bg-gray-200 object-cover" />
				{:else}
					<span class="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-black font-display text-sm font-bold text-gold-300">
						{p.name.trim().charAt(0).toUpperCase()}
					</span>
				{/if}
				<input class="inline-edit flex-1 font-medium" value={p.name} disabled={!session.canManage} onchange={(e) => save(p, 'name', e.currentTarget.value)} />
				<input class="inline-edit flex-1 text-gray-500" value={p.nickname ?? ''} placeholder={t('players.nickname')} disabled={!session.canManage}
					onchange={(e) => save(p, 'nickname', e.currentTarget.value)} />
				{#if p.fpb_license}<span class="hidden font-mono text-xs text-gray-400 sm:inline" title={p.fpb_club ?? ''}>{t('fpb.license', { n: p.fpb_license })}</span>{/if}
				{#if session.canManage}<button class="link-danger px-2" onclick={() => remove(p)}>{t('common.remove')}</button>{/if}
			</div>
		{:else}
			<p class="p-6 text-center text-sm text-gray-500">{t('players.none')}</p>
		{/each}
	</div>
</div>
