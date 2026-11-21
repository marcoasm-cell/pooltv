<!-- Pool tables and their OBS overlay links -->
<script lang="ts">
	import { api } from '#lib/api.ts';
	import { errorMessage, overlayUrl } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import type { Account, PoolTable } from '#lib/types.ts';

	let tables = $state<PoolTable[]>([]);
	let account = $state<Account | null>(null);
	let newName = $state('');
	let error = $state('');
	let copied = $state('');

	async function load() {
		[tables, account] = await Promise.all([api<PoolTable[]>('/pool_tables'), api<Account>('/account')]);
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

	async function copy(url: string) {
		await navigator.clipboard.writeText(url);
		copied = url;
		setTimeout(() => (copied = ''), 1500);
	}

	const add = (e: SubmitEvent) => {
		e.preventDefault();
		run(async () => {
			await api('/pool_tables', { body: { name: newName } });
			newName = '';
		});
	};
	const rename = (table: PoolTable, name: string) => name !== table.name && run(() => api(`/pool_tables/${table.id}`, { method: 'PATCH', body: { name } }));
	const toggle = (table: PoolTable) => run(() => api(`/pool_tables/${table.id}`, { method: 'PATCH', body: { active: !table.active } }));
	const toggleOverlay = (table: PoolTable) =>
		run(() => api(`/pool_tables/${table.id}`, { method: 'PATCH', body: { overlay_settings: { visible: table.overlay.visible === false ? true : false } } }));
	const regenerate = (table: PoolTable) =>
		confirm(t('tables.confirmRegenerate', { name: table.name })) && run(() => api(`/pool_tables/${table.id}/regenerate_token`, { method: 'POST' }));
	const regenerateAll = () =>
		confirm(t('tables.confirmRegenerateAll')) && run(() => api('/account/regenerate_overlay_token', { method: 'POST' }));
	const remove = (table: PoolTable) => confirm(t('common.confirmDelete', { name: table.name })) && run(() => api(`/pool_tables/${table.id}`, { method: 'DELETE' }));
	// Swaps places with the neighbouring table
	const move = (i: number, delta: number) => {
		const [a, b] = [tables[i], tables[i + delta]];
		run(() =>
			Promise.all([
				api(`/pool_tables/${a.id}`, { method: 'PATCH', body: { position: i + delta } }),
				api(`/pool_tables/${b.id}`, { method: 'PATCH', body: { position: i } })
			])
		);
	};
</script>

{#snippet link(url: string, onRegenerate: () => void)}
	<div class="flex flex-wrap items-center gap-2">
		<code class="min-w-0 flex-1 truncate rounded-md border border-gray-200 bg-gray-50 px-2.5 py-1.5 font-mono text-xs text-gray-600">{url}</code>
		<button class="btn btn-sm {copied === url ? 'btn-primary' : 'btn-ghost'}" onclick={() => copy(url)}>
			{copied === url ? t('tables.copied') : t('tables.copy')}
		</button>
		<a class="btn btn-ghost btn-sm" href={url} target="_blank" rel="noopener">{t('tables.preview')}</a>
		<button class="link-danger px-1" onclick={onRegenerate}>{t('tables.newLink')}</button>
	</div>
{/snippet}

<header class="mb-8">
	<p class="eyebrow mb-1">{t('tables.eyebrow')}</p>
	<h1 class="page-title">{t('tables.title')}</h1>
	<p class="mt-3 max-w-2xl text-sm text-gray-600">
		{t('tables.help1')} <b>{t('tables.browserSource')}</b>{t('tables.help2')}
	</p>
</header>
{#if error}<p class="alert-error mb-4">{error}</p>{/if}

{#if account?.overlay_token}
	<section class="mb-6 rounded-2xl bg-black p-1 shadow-lg shadow-black/20">
		<div class="rounded-xl bg-white p-5">
			<div class="mb-3 flex items-center gap-2">
				<h2 class="text-lg">{t('tables.all')}</h2>
				<span class="badge bg-gold-100 text-gold-700">{t('tables.oneLink')}</span>
			</div>
			{@render link(overlayUrl(`/overlay/all/${account.overlay_token}`), regenerateAll)}
			<p class="mt-3 text-xs text-gray-500">{t('tables.layoutHelp')} <code class="rounded bg-gray-100 px-1">?layout=split|grid|sidebar|ticker</code>.</p>
		</div>
	</section>
{/if}

<div class="space-y-3">
	{#each tables as table, i (table.id)}
		<section class="card p-5 transition" class:opacity-55={!table.active}>
			<div class="mb-3 flex flex-wrap items-center gap-2">
				<span class="h-3 w-3 shrink-0 rounded-full ring-4 ring-gold-100 {table.active ? 'bg-gold-400' : 'bg-gray-300'}"></span>
				<input class="inline-edit font-display text-xl font-bold" value={table.name}
					onchange={(e) => rename(table, e.currentTarget.value)} />
				<div class="ml-auto flex flex-wrap items-center gap-1 text-sm text-gray-600">
					<span class="mr-2 flex overflow-hidden rounded-md ring-1 ring-gray-200">
						<button class="px-2 py-0.5 hover:bg-gray-100 disabled:opacity-30" disabled={i === 0} onclick={() => move(i, -1)} aria-label={t('common.moveUp')}>↑</button>
						<button class="border-l border-gray-200 px-2 py-0.5 hover:bg-gray-100 disabled:opacity-30" disabled={i === tables.length - 1} onclick={() => move(i, 1)} aria-label={t('common.moveDown')}>↓</button>
					</span>
					<label class="mr-2 flex items-center gap-1.5"><input type="checkbox" checked={table.overlay.visible !== false} onchange={() => toggleOverlay(table)} /> {t('tables.overlayOn')}</label>
					<label class="mr-2 flex items-center gap-1.5"><input type="checkbox" checked={table.active} onchange={() => toggle(table)} /> {t('tables.active')}</label>
					<button class="link-danger" onclick={() => remove(table)}>{t('common.delete')}</button>
				</div>
			</div>
			{#if table.overlay_token}
				{@render link(overlayUrl(`/overlay/table/${table.overlay_token}`), () => regenerate(table))}
			{/if}
		</section>
	{/each}
</div>

<form class="card mt-4 flex gap-2 p-3" onsubmit={add}>
	<input class="field flex-1" placeholder={t('tables.newPh')} bind:value={newName} required />
	<button class="btn btn-primary">{t('tables.add')}</button>
</form>
