<script lang="ts">
	import { api } from '#lib/api.ts';
	import { errorMessage } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { User } from '#lib/types.ts';

	let users = $state<User[]>([]);
	let error = $state('');
	let newUser = $state({ name: '', email: '', password: '', role: 'scorer' as User['role'] });

	async function load() {
		users = await api<User[]>('/users');
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

	const addUser = (e: SubmitEvent) => {
		e.preventDefault();
		run(async () => {
			await api('/users', { body: newUser });
			newUser = { name: '', email: '', password: '', role: 'scorer' };
		});
	};
</script>

<header class="mb-8">
	<p class="eyebrow mb-1">{t('settings.title')}</p>
	<h1 class="page-title">{t('settings.users')}</h1>
</header>
{#if error}<p class="alert-error mb-4">{error}</p>{/if}

<section class="card p-6">
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
