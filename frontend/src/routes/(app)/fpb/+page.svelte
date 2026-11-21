<!-- Import of teams, rosters and athletes from the FPB portal (admins only) -->
<script lang="ts">
	import { goto } from '$app/navigation';
	import { api } from '#lib/api.ts';
	import { errorMessage } from '#lib/format.ts';
	import { t, tn } from '#lib/i18n/index.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { FpbAthlete, FpbImportResult, FpbTeam } from '#lib/types.ts';

	let tab = $state<'teams' | 'athletes'>('teams');
	let error = $state('');
	let busy = $state(false);
	let result = $state<FpbImportResult | null>(null);

	let variants = $state<{ key: string; name: string }[]>([]);
	let variant = $state('');
	let competitions = $state<{ code: string; name: string }[]>([]);
	let competition = $state('');
	let teams = $state<FpbTeam[]>([]);
	let pickedTeams = $state<string[]>([]);

	let q = $state('');
	let athletes = $state<FpbAthlete[]>([]);
	let pickedAthletes = $state<number[]>([]);
	let searched = $state(false);

	$effect(() => {
		if (!session.canManage) goto('/teams');
	});

	async function run<T>(fn: () => Promise<T>): Promise<T | undefined> {
		error = '';
		busy = true;
		try {
			return await fn();
		} catch (e) {
			error = errorMessage(e);
		} finally {
			busy = false;
		}
	}

	async function loadTeams() {
		pickedTeams = [];
		teams = (await run(() => api<FpbTeam[]>(`/fpb/teams?${new URLSearchParams({ variant, competition })}`))) ?? [];
	}

	async function pickVariant(key: string) {
		variant = key;
		competitions = [];
		teams = [];
		const res = await run(() => api<{ competitions: { code: string; name: string }[]; selected: string }>(`/fpb/competitions?${new URLSearchParams({ variant: key })}`));
		if (!res) return;
		competitions = res.competitions;
		competition = res.selected;
		await loadTeams();
	}

	$effect(() => {
		run(() => api<{ key: string; name: string }[]>('/fpb/variants')).then((v) => {
			variants = v ?? [];
			if (variants.length) pickVariant(variants[0].key);
		});
	});

	async function search(e: SubmitEvent) {
		e.preventDefault();
		pickedAthletes = [];
		athletes = (await run(() => api<FpbAthlete[]>(`/fpb/athletes?${new URLSearchParams({ q })}`))) ?? [];
		searched = true;
	}

	async function doImport(body: { teams?: string[]; licenses?: number[] }, refresh: () => Promise<unknown>) {
		result = null;
		const res = await run(() => api<FpbImportResult>('/fpb/import', { body }));
		if (!res) return;
		result = res;
		await refresh();
	}

	async function sync() {
		result = null;
		result = (await run(() => api<FpbImportResult>('/fpb/sync', { method: 'POST' }))) ?? null;
	}

	const toggle = <T,>(list: T[], item: T) => (list.includes(item) ? list.filter((x) => x !== item) : [...list, item]);
	const allPicked = $derived(teams.length > 0 && pickedTeams.length === teams.length);
</script>

<header class="mb-6">
	<p class="eyebrow mb-1">{t('fpb.eyebrow')}</p>
	<h1 class="page-title">{t('fpb.title')}</h1>
	<p class="mt-2 max-w-2xl text-sm text-gray-600">{t('fpb.intro')}</p>
</header>

{#if error}<p class="alert-error mb-4">{error}</p>{/if}
{#if result}
	<p class="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-800">
		{Object.values(result).every((n) => n === 0)
			? t('fpb.upToDate')
			: t('fpb.result', { pc: result.players_created, pu: result.players_updated, tc: result.teams_created, tu: result.teams_updated, ra: result.roster_added, ph: result.photos_queued })}
	</p>
{/if}

<div class="mb-5 flex flex-wrap items-center gap-2">
	<button class="btn btn-sm {tab === 'teams' ? 'btn-dark' : 'btn-ghost'}" onclick={() => (tab = 'teams')}>{t('fpb.tabTeams')}</button>
	<button class="btn btn-sm {tab === 'athletes' ? 'btn-dark' : 'btn-ghost'}" onclick={() => (tab = 'athletes')}>{t('fpb.tabAthletes')}</button>
	<span class="ml-auto text-xs text-gray-500">{busy ? t('fpb.working') : t('fpb.syncHint')}</span>
	<button class="btn btn-ghost btn-sm" disabled={busy} onclick={sync}>{t('fpb.sync')}</button>
</div>

{#if tab === 'teams'}
	<div class="card mb-4 grid gap-3 p-4 md:grid-cols-[14rem_1fr]">
		<label class="lbl">{t('fpb.variant')}
			<select class="field" value={variant} disabled={busy} onchange={(e) => pickVariant(e.currentTarget.value)}>
				{#each variants as v (v.key)}<option value={v.key}>{v.name}</option>{/each}
			</select>
		</label>
		<label class="lbl">{t('fpb.competition')}
			<select class="field" bind:value={competition} disabled={busy || !competitions.length} onchange={loadTeams}>
				{#each competitions as c (c.code)}<option value={c.code}>{c.name}</option>{/each}
			</select>
		</label>
	</div>

	<div class="card overflow-hidden">
		<div class="flex items-center gap-3 border-b border-gray-200 bg-gray-50/70 px-4 py-3">
			<label class="flex items-center gap-2 text-sm">
				<input type="checkbox" checked={allPicked} disabled={!teams.length}
					onchange={() => (pickedTeams = allPicked ? [] : teams.map((tm) => tm.code))} />
				{t('fpb.selectAll')}
			</label>
			<button class="btn btn-primary btn-sm ml-auto" disabled={busy || !pickedTeams.length}
				onclick={() => doImport({ teams: pickedTeams }, loadTeams)}>
				{tn('fpb.importTeams', pickedTeams.length)}
			</button>
		</div>
		<div class="divide-y divide-gray-200">
			{#each teams as tm (tm.code)}
				<label class="flex cursor-pointer items-center gap-3 px-4 py-2 transition hover:bg-gray-50">
					<input type="checkbox" checked={pickedTeams.includes(tm.code)} onchange={() => (pickedTeams = toggle(pickedTeams, tm.code))} />
					<span class="min-w-0 flex-1">
						<span class="block truncate font-medium">{tm.name}</span>
						<span class="block truncate text-xs text-gray-500">{[tm.club, tm.district, tm.status].filter(Boolean).join(' · ')}</span>
					</span>
					{#if tm.team_id}<span class="badge bg-gold-100 text-gold-700">{t('fpb.imported')}</span>{/if}
					<span class="font-mono text-xs text-gray-400">{tm.code}</span>
				</label>
			{:else}
				<p class="p-6 text-center text-sm text-gray-500">{busy ? t('fpb.working') : t('fpb.noTeams')}</p>
			{/each}
		</div>
	</div>
{:else}
	<form class="card mb-4 flex gap-2 p-3" onsubmit={search}>
		<input class="field flex-1" placeholder={t('fpb.searchPh')} bind:value={q} minlength="2" required />
		<button class="btn btn-dark" disabled={busy}>{t('fpb.search')}</button>
	</form>

	<div class="card overflow-hidden">
		<div class="flex items-center gap-3 border-b border-gray-200 bg-gray-50/70 px-4 py-3">
			<span class="text-xs text-gray-500">{tn('players.count', athletes.length)}</span>
			<button class="btn btn-primary btn-sm ml-auto" disabled={busy || !pickedAthletes.length}
				onclick={() => doImport({ licenses: pickedAthletes }, async () => {
					athletes = await api<FpbAthlete[]>(`/fpb/athletes?${new URLSearchParams({ q })}`);
					pickedAthletes = [];
				})}>
				{tn('fpb.importAthletes', pickedAthletes.length)}
			</button>
		</div>
		<div class="divide-y divide-gray-200">
			{#each athletes as a (a.license)}
				<label class="flex cursor-pointer items-center gap-3 px-4 py-2 transition hover:bg-gray-50">
					<input type="checkbox" checked={pickedAthletes.includes(a.license)} onchange={() => (pickedAthletes = toggle(pickedAthletes, a.license))} />
					<span class="min-w-0 flex-1">
						<span class="block truncate font-medium">{a.name}</span>
						<span class="block truncate text-xs text-gray-500">{[a.full_name, a.club, a.district].filter(Boolean).join(' · ')}</span>
					</span>
					{#if a.player_id}<span class="badge bg-gold-100 text-gold-700">{t('fpb.importedPlayer')}</span>{/if}
					<span class="font-mono text-xs text-gray-400">{a.license}</span>
				</label>
			{:else}
				{#if searched}<p class="p-6 text-center text-sm text-gray-500">{t('fpb.noAthletes')}</p>{/if}
			{/each}
		</div>
	</div>
{/if}
