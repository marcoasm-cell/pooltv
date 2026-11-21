<!-- Every account (club) on the platform: platform admins only -->
<script lang="ts">
	import { goto } from '$app/navigation';
	import { api } from '#lib/api.ts';
	import { errorMessage } from '#lib/format.ts';
	import { i18n, t, tn } from '#lib/i18n/index.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { Account, AdminAccount, User } from '#lib/types.ts';

	let accounts = $state<AdminAccount[]>([]);
	let form = $state({ name: '', owner: { name: '', email: '', password: '' } });
	let q = $state('');
	let error = $state('');

	const filtered = $derived(
		accounts.filter((a) => `${a.name} ${a.owners.map((o) => `${o.name} ${o.email}`).join(' ')}`.toLowerCase().includes(q.toLowerCase()))
	);

	async function load() {
		accounts = await api<AdminAccount[]>('/admin/accounts');
	}
	$effect(() => {
		if (!session.isAdmin) {
			goto('/dashboard');
			return;
		}
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
			await api('/admin/accounts', { body: form });
			form = { name: '', owner: { name: '', email: '', password: '' } };
		});
	};
	const rename = (a: AdminAccount, name: string) => run(() => api(`/admin/accounts/${a.id}`, { method: 'PATCH', body: { name } }));
	const remove = (a: AdminAccount) =>
		confirm(t('accounts.confirmDelete', { name: a.name })) && run(() => api(`/admin/accounts/${a.id}`, { method: 'DELETE' }));

	/** Switches the session to the account and reloads, so live updates follow it */
	async function enter(a: AdminAccount) {
		error = '';
		try {
			const data = await api<{ user: User; account: Account }>(`/admin/accounts/${a.id}/enter`, { method: 'POST' });
			session.set({ token: session.token!, ...data });
			location.assign('/dashboard');
		} catch (e) {
			error = errorMessage(e);
		}
	}

	const created = (iso: string) => new Date(iso).toLocaleDateString(i18n.locale);
</script>

<header class="mb-8">
	<p class="eyebrow mb-1">{t('accounts.eyebrow')}</p>
	<h1 class="page-title">{t('accounts.title')}</h1>
</header>
{#if error}<p class="alert-error mb-4">{error}</p>{/if}

<form class="card mb-5 p-4" onsubmit={add}>
	<h2 class="mb-1 text-lg">{t('accounts.new')}</h2>
	<p class="mb-3 text-xs text-gray-500">{t('accounts.newHelp')}</p>
	<div class="flex flex-wrap gap-2">
		<input class="field min-w-48 flex-1" placeholder={t('accounts.clubName')} bind:value={form.name} required />
		<input class="field min-w-40 flex-1" placeholder={t('accounts.ownerName')} bind:value={form.owner.name} required />
		<input class="field min-w-48 flex-1" type="email" placeholder={t('accounts.ownerEmail')} bind:value={form.owner.email} required autocomplete="off" />
		<input class="field min-w-40 flex-1" type="password" placeholder={t('common.password')} bind:value={form.owner.password} required minlength="6"
			autocomplete="new-password" />
		<button class="btn btn-primary">{t('accounts.create')}</button>
	</div>
</form>

<div class="card overflow-hidden">
	<div class="flex items-center gap-3 border-b border-gray-200 bg-gray-50/70 px-4 py-3">
		<input class="field max-w-xs py-1.5" placeholder={t('accounts.search')} bind:value={q} />
		<span class="ml-auto text-xs text-gray-500">{tn('accounts.count', filtered.length)}</span>
	</div>
	<div class="divide-y divide-gray-200">
		{#each filtered as a (a.id)}
			{@const own = a.id === session.user?.account_id}
			{@const current = a.id === session.account?.id}
			<div class="flex flex-wrap items-center gap-x-3 gap-y-1 px-4 py-3 transition hover:bg-gray-50">
				<div class="min-w-48 flex-1">
					<div class="flex items-center gap-2">
						<input class="inline-edit flex-1 font-medium" value={a.name} onchange={(e) => rename(a, e.currentTarget.value)} />
						{#if own}<span class="badge bg-gray-100 text-gray-600">{t('accounts.yours')}</span>{/if}
						{#if current && !own}<span class="badge bg-gold-100 text-gold-700">{t('accounts.viewing')}</span>{/if}
					</div>
					<div class="truncate px-1 text-xs text-gray-500">
						{a.owners.map((o) => `${o.name} · ${o.email}`).join(', ') || t('accounts.noOwner')}
					</div>
				</div>
				<span class="text-xs text-gray-500">{tn('accounts.users', a.users_count)}</span>
				<span class="hidden text-xs text-gray-400 sm:inline">{created(a.created_at)}</span>
				{#if !current}<button class="btn btn-ghost btn-sm" onclick={() => enter(a)}>{t('accounts.enter')}</button>{/if}
				{#if !own}<button class="link-danger px-2" onclick={() => remove(a)}>{t('common.delete')}</button>{/if}
			</div>
		{:else}
			<p class="p-6 text-center text-sm text-gray-500">{t('accounts.none')}</p>
		{/each}
	</div>
</div>
