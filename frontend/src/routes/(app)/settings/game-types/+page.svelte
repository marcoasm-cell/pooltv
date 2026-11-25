<script lang="ts">
	import { api } from '#lib/api.ts';
	import { errorMessage } from '#lib/format.ts';
	import { t, tk } from '#lib/i18n/index.svelte.ts';
	import type { GameType } from '#lib/types.ts';

	let gameTypes = $state<GameType[]>([]);
	let error = $state('');
	let newGame = $state({ key: '', name: '', scoring_mode: 'racks', default_target: 5, break_rule: 'alternate' });

	async function load() {
		gameTypes = await api<GameType[]>('/game_types');
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

	const addGame = (e: SubmitEvent) => {
		e.preventDefault();
		run(async () => {
			await api('/game_types', { body: newGame });
			newGame = { key: '', name: '', scoring_mode: 'racks', default_target: 5, break_rule: 'alternate' };
		});
	};
</script>

<header class="mb-8">
	<p class="eyebrow mb-1">{t('settings.title')}</p>
	<h1 class="page-title">{t('settings.gameTypes')}</h1>
</header>
{#if error}<p class="alert-error mb-4">{error}</p>{/if}

<section class="card p-6">
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
