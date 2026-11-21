<!-- Teams and their rosters -->
<script lang="ts">
	import { api, photoUrl } from '#lib/api.ts';
	import { errorMessage } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { session } from '#lib/session.svelte.ts';
	import type { Player, Team } from '#lib/types.ts';

	let teams = $state<Team[]>([]);
	let players = $state<Player[]>([]);
	let form = $state({ name: '' });
	let error = $state('');

	async function load() {
		[teams, players] = await Promise.all([api<Team[]>('/teams'), api<Player[]>('/players')]);
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
			await api('/teams', { body: form });
			form = { name: '' };
		});
	};
	const save = (team: Team, body: Partial<Team>) => run(() => api(`/teams/${team.id}`, { method: 'PATCH', body }));
	const setRoster = (team: Team, roster: { player_id: number; captain: boolean }[]) =>
		run(() => api(`/teams/${team.id}/roster`, { method: 'PUT', body: { roster } }));
	const rosterOf = (team: Team) => (team.roster ?? []).map((p) => ({ player_id: p.id, captain: p.captain }));
	const remove = (team: Team) => confirm(t('common.confirmDelete', { name: team.name })) && run(() => api(`/teams/${team.id}`, { method: 'DELETE' }));
</script>

<header class="mb-8 flex flex-wrap items-end gap-3">
	<div class="flex-1">
		<p class="eyebrow mb-1">{t('teams.eyebrow')}</p>
		<h1 class="page-title">{t('teams.title')}</h1>
	</div>
	{#if session.canManage}<a href="/fpb" class="btn btn-ghost btn-sm">{t('fpb.link')}</a>{/if}
</header>
{#if error}<p class="alert-error mb-4">{error}</p>{/if}

{#if session.canManage}
	<form class="card mb-6 flex flex-wrap gap-2 p-3" onsubmit={add}>
		<input class="field flex-1" placeholder={t('teams.namePh')} bind:value={form.name} required />
		<button class="btn btn-primary">{t('teams.add')}</button>
	</form>
{/if}

<div class="grid gap-5 md:grid-cols-2">
	{#each teams as team (team.id)}
		{@const roster = rosterOf(team)}
		<section class="card overflow-hidden">
			<div class="p-5">
				<div class="mb-4 flex items-center gap-2">
					<input class="inline-edit min-w-0 flex-1 font-display text-xl font-bold" value={team.name} disabled={!session.canManage} onchange={(e) => save(team, { name: e.currentTarget.value })} />
				</div>
				{#if team.fpb_code}<p class="-mt-2 mb-3 px-1.5 text-xs text-gray-500">{[team.fpb_club, team.fpb_code].filter(Boolean).join(' · ')}</p>{/if}
				<ul class="mb-4 divide-y divide-gray-100">
					{#each team.roster ?? [] as p (p.id)}
						<li class="flex items-center gap-2 py-1.5 text-sm">
							{#if p.photo_url}
								<img src={photoUrl(p.photo_url)} alt="" loading="lazy" class="h-6 w-6 shrink-0 rounded-full bg-gray-200 object-cover" />
							{:else}
								<span class="h-6 w-6 shrink-0 rounded-full bg-gray-200"></span>
							{/if}
							<span class="flex-1">{p.display_name}</span>
							{#if session.canManage}
								<label class="flex items-center gap-1 text-xs text-gray-500">
									<input type="checkbox" checked={p.captain}
										onchange={() => setRoster(team, roster.map((r) => (r.player_id === p.id ? { ...r, captain: !r.captain } : r)))} />
									{t('teams.captain')}
								</label>
								<button class="link-danger ml-2" onclick={() => setRoster(team, roster.filter((r) => r.player_id !== p.id))}>{t('common.remove')}</button>
							{:else if p.captain}
								<span class="badge bg-gold-100 text-gold-700">{t('teams.captain')}</span>
							{/if}
						</li>
					{:else}
						<li class="py-2 text-sm text-gray-400">{t('teams.noPlayers')}</li>
					{/each}
				</ul>
				{#if session.canManage}
					<div class="flex items-center gap-2">
						<select class="field flex-1 py-1.5 text-sm"
							onchange={(e) => {
								const id = Number(e.currentTarget.value);
								e.currentTarget.value = '';
								if (id) setRoster(team, [...roster, { player_id: id, captain: false }]);
							}}>
							<option value="">{t('teams.addPlayer')}</option>
							{#each players.filter((p) => !roster.some((r) => r.player_id === p.id)) as p (p.id)}
								<option value={p.id}>{p.name}</option>
							{/each}
						</select>
						<button class="link-danger px-2" onclick={() => remove(team)}>{t('teams.delete')}</button>
					</div>
				{/if}
			</div>
		</section>
	{/each}
</div>
