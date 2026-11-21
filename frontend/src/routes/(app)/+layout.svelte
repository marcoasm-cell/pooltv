<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { api } from '#lib/api.ts';
	import Brand from '#lib/components/Brand.svelte';
	import Credit from '#lib/components/Credit.svelte';
	import LangSwitch from '#lib/components/LangSwitch.svelte';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { live } from '#lib/live.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { Account, User } from '#lib/types.ts';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();
	let menuOpen = $state(false);
	let userOpen = $state(false);
	let userMenu = $state<HTMLElement>();

	const initials = $derived(
		(session.user?.name ?? '')
			.split(/\s+/)
			.filter(Boolean)
			.map((w) => w[0])
			.filter((_, i, a) => i === 0 || i === a.length - 1)
			.join('')
			.toUpperCase() || '?'
	);

	function closeUserMenu(e: MouseEvent) {
		if (userOpen && userMenu && !userMenu.contains(e.target as Node)) userOpen = false;
	}

	const links = $derived([
		{ href: '/dashboard', label: t('nav.live') },
		{ href: '/tournaments', label: t('nav.tournaments') },
		{ href: '/players', label: t('nav.players') },
		{ href: '/teams', label: t('nav.teams') },
		...(session.canManage ? [{ href: '/tables', label: t('nav.tables') }, { href: '/settings', label: t('nav.settings') }] : []),
		...(session.isAdmin ? [{ href: '/accounts', label: t('nav.accounts') }] : [])
	]);

	/** A platform admin back to their own account; reloads so live updates follow */
	async function leaveAccount() {
		const data = await api<{ user: User; account: Account }>(`/admin/accounts/${session.user!.account_id}/enter`, { method: 'POST' });
		session.set({ token: session.token!, ...data });
		location.assign('/accounts');
	}

	$effect(() => {
		if (!session.token) {
			goto('/login');
			return;
		}
		live.start();
		return () => live.stop();
	});

	// The user and account saved on this device may be stale (role or account changed)
	$effect(() => {
		const token = session.token;
		if (!token) return;
		api<{ user: User; account: Account }>('/me')
			.then((data) => session.token === token && session.set({ token, ...data }))
			.catch(() => {});
	});

	// The scoring screen runs full-screen on a tablet: no nav, no footer
	const scoring = $derived(page.url.pathname.startsWith('/score/'));

	async function logout() {
		await api('/logout', { method: 'DELETE' }).catch(() => {});
		session.clear();
	}
</script>

<svelte:window onclick={closeUserMenu} onkeydown={(e) => e.key === 'Escape' && (userOpen = false)} />

{#if session.token}
	<div class="min-h-screen bg-gray-100 text-gray-900">
		{#if !scoring}
		<nav class="sticky top-0 z-20 bg-black text-white">
			<div class="mx-auto flex h-16 max-w-6xl items-center gap-6 px-4">
				<a href="/dashboard" class="shrink-0"><Brand /></a>

				<!-- Links: centred on desktop, a drop-down on phones -->
				<div class="{menuOpen ? 'flex' : 'hidden'} absolute top-full right-0 left-0 flex-col border-t border-white/10 bg-black px-4 py-2 shadow-2xl
					md:static md:mx-auto md:flex md:flex-row md:items-center md:gap-1 md:border-0 md:p-0 md:shadow-none">
					{#each links as link (link.href)}
						{@const active = page.url.pathname.startsWith(link.href)}
						<a href={link.href} onclick={() => (menuOpen = false)}
							class="nav-link {active ? 'text-gold-300' : 'text-white/85 hover:text-gold-300'}">
							{link.label}
						</a>
					{/each}
				</div>

				<div class="ml-auto flex items-center gap-4 md:ml-0">
					<a href="/matches/new" class="btn btn-primary btn-sm py-2 pl-5"><span class="btn-icon">+</span>{t('nav.newMatch')}</a>

					<!-- Current user: avatar with a drop-down for language and sign-out -->
					<div class="relative" bind:this={userMenu}>
						<button type="button"
							class="grid h-9 w-9 place-items-center rounded-full bg-white/10 font-condensed text-sm font-bold tracking-wider text-white ring-1 transition hover:ring-gold-300
								{userOpen ? 'ring-gold-300' : 'ring-white/20'}"
							aria-haspopup="menu" aria-expanded={userOpen} aria-label={t('nav.account')} title={session.user?.name}
							onclick={() => { userOpen = !userOpen; menuOpen = false; }}>
							{initials}
						</button>
						{#if userOpen}
							<div class="absolute top-full right-0 mt-2 w-64 overflow-hidden rounded-xl bg-white text-gray-900 shadow-2xl ring-1 ring-black/5" role="menu">
								<div class="border-b border-gray-100 px-4 py-3">
									<div class="truncate font-semibold">{session.user?.name}</div>
									<div class="truncate text-sm text-gray-500">{session.user?.email}</div>
									<div class="mt-1 truncate text-xs text-gray-400">{session.account?.name}</div>
								</div>
								<div class="flex items-center justify-between border-b border-gray-100 px-4 py-3">
									<span class="text-sm text-gray-600">{t('lang.label')}</span>
									<LangSwitch tone="light" />
								</div>
								<button type="button" role="menuitem" class="block w-full px-4 py-3 text-left text-sm font-medium text-gray-700 transition hover:bg-gray-50 hover:text-gray-900"
									onclick={logout}>
									{t('nav.signOut')}
								</button>
							</div>
						{/if}
					</div>
					<button class="grid h-9 w-9 place-items-center rounded-full text-lg text-white/80 hover:bg-white/10 md:hidden" onclick={() => { menuOpen = !menuOpen; userOpen = false; }} aria-label={t('nav.menu')}>
						{menuOpen ? '✕' : '☰'}
					</button>
				</div>
			</div>
			{#if session.isVisiting}
				<div class="flex items-center justify-center gap-3 border-t border-white/10 px-4 py-1.5 text-sm text-white/70">
					<span>{t('nav.viewing')} <strong class="font-semibold text-white">{session.account?.name}</strong></span>
					<button type="button" class="text-gold-300 underline-offset-2 hover:underline" onclick={leaveAccount}>{t('nav.backToMine')}</button>
				</div>
			{/if}
			{#if live.status === 'disconnected'}
				<div class="bg-red-600 px-4 py-1.5 text-center text-sm font-semibold">{t('nav.offline')}</div>
			{/if}
		</nav>
		{/if}
		<!-- The scoring screen uses the whole tablet -->
		<main class={scoring ? '' : 'mx-auto max-w-6xl px-4 py-10'}>
			{@render children()}
		</main>
		{#if !scoring}
			<footer class="border-t border-gray-200">
				<Credit class="mx-auto max-w-6xl px-4 py-6 text-center" />
			</footer>
		{/if}
	</div>
{/if}

<style lang="postcss">
	@reference "../../app.css";

	.nav-link {
		@apply px-3 py-2.5 font-condensed text-[15px] font-semibold tracking-[0.12em] uppercase transition-colors md:py-1;
	}
</style>
