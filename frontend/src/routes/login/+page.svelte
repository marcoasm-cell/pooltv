<script lang="ts">
	import { goto } from '$app/navigation';
	import { api } from '#lib/api.ts';
	import Brand from '#lib/components/Brand.svelte';
	import Credit from '#lib/components/Credit.svelte';
	import LangSwitch from '#lib/components/LangSwitch.svelte';
	import { errorMessage } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { Account, User } from '#lib/types.ts';

	// No public signup: accounts are created by platform admins, on request
	const CONTACT_EMAIL = 'marco.a.s.m@hotmail.com';
	let form = $state({ email: '', password: '' });
	let error = $state('');
	let busy = $state(false);

	async function submit(e: SubmitEvent) {
		e.preventDefault();
		busy = true;
		error = '';
		try {
			const data = await api<{ token: string; user: User; account: Account }>('/login', {
				body: form,
				auth: false
			});
			session.set(data);
			await goto('/dashboard');
		} catch (err) {
			error = errorMessage(err);
		} finally {
			busy = false;
		}
	}
</script>

<div class="surface-dark relative flex min-h-screen items-center justify-center overflow-hidden p-4">
	<div class="absolute top-4 right-4"><LangSwitch /></div>
	<div class="relative w-full max-w-sm">
		<div class="mb-8 text-center">
			<Brand size="lg" />
			<p class="mt-3 text-sm text-white/60">{t('login.tagline')}</p>
		</div>

		<div>
			<form onsubmit={submit} class="space-y-4 rounded-2xl bg-white p-7 shadow-2xl shadow-black/40 ring-1 ring-white/10">
				<h1 class="text-2xl text-gray-950">{t('login.welcome')}</h1>
				<label class="lbl">{t('common.email')}<input class="field" type="email" bind:value={form.email} required autocomplete="email" /></label>
				<label class="lbl">{t('common.password')}
					<input class="field" type="password" bind:value={form.password} required minlength="6"
						autocomplete="current-password" />
				</label>
				{#if error}<p class="alert-error">{error}</p>{/if}
				<button class="btn btn-primary w-full py-2.5" disabled={busy}>
					{t('login.signIn')}
				</button>
				<div class="h-px bg-gray-200"></div>
				<p class="text-center text-sm text-gray-500">
					{t('login.newClub')}
					<a href="mailto:{CONTACT_EMAIL}" class="font-medium text-gray-700 underline-offset-2 transition hover:text-gold-600 hover:underline">{CONTACT_EMAIL}</a>
				</p>
			</form>
		</div>
		<Credit tone="dark" class="mt-6 text-center" />
	</div>
</div>
