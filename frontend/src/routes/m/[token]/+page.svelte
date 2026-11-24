<!--
  Public page of one match, reached by its QR code: the score as it happens, no sign-in.
  A match of a tournament links to the tournament's page.
-->
<script lang="ts">
	import { page } from '$app/state';
	import { api } from '#lib/api.ts';
	import type { LiveStatus } from '#lib/cable.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { matchCaption, raceLabel, teamTargetLabel } from '#lib/overlay/state.svelte.ts';
	import Avatar from '#lib/public/Avatar.svelte';
	import { follow } from '#lib/public/follow.ts';
	import Shell from '#lib/public/Shell.svelte';
	import type { Branding, Match, PublicTable, Side } from '#lib/types.ts';

	const token = $derived(page.params.token!);
	let match = $state<Match | null>(null);
	let branding = $state<Branding | null>(null);
	let tables = $state<PublicTable[]>([]);
	let error = $state('');
	let status = $state<LiveStatus>('connecting');

	async function load() {
		try {
			const data = await api<{ match: Match; branding: Branding; tables: PublicTable[] }>(`/public/matches/${token}`, { auth: false });
			({ match, branding, tables } = data);
			error = '';
		} catch (e) {
			error = (e as Error).message;
		}
	}

	$effect(() =>
		follow('match', token, load, {
			onStatus: (s) => (status = s),
			onMessage: (msg) => {
				if (msg.type !== 'match' || msg.match.public_token !== token) return false;
				match = msg.match;
				return true;
			}
		})
	);

	const SIDES = ['home', 'away'] as const;
	const table = $derived(tables.find((x) => x.id === match?.pool_table_id)?.name);
	const caption = $derived(match ? matchCaption(match) : '');
	const dots = $derived(!!match && match.game_type.scoring_mode === 'racks' && match.target > 1 && match.target <= 21);
	const lost = (m: Match, side: Side) => !!m.winner_side && m.winner_side !== side;
</script>

<svelte:head><title>{match ? t('public.title', { name: `${match.home.name} ${t('common.vs')} ${match.away.name}` }) : 'Pool TV'}</title></svelte:head>

<Shell {branding} {status}>
	{#if error && !match}
		<p class="card p-6 text-center text-gray-600">{t('public.notFound')}</p>
	{:else if match}
		{@const tm = match.team_match}
		<div class="mx-auto max-w-2xl">
			{#if caption}<p class="eyebrow mb-2">{caption}</p>{/if}
			<div class="mb-5 flex flex-wrap items-center gap-1.5 text-xs">
				{#if match.status === 'live'}
					<span class="badge badge-live">{t('common.live')}</span>
				{:else if match.status === 'finished'}
					<span class="badge bg-gray-950 text-gold-300">{t('common.final')}</span>
				{:else}
					<span class="badge bg-white text-gray-600 ring-1 ring-gray-200">{t('public.notStarted')}</span>
				{/if}
				{#each [table, match.game_type.name, raceLabel(match)].filter(Boolean) as chip (chip)}
					<span class="rounded-full bg-white px-2.5 py-1 font-medium text-gray-600 ring-1 ring-gray-200">{chip}</span>
				{/each}
			</div>

			<section class="card overflow-hidden">
				{#if tm}
					<!-- Team score above the game -->
					<div class="flex items-center gap-3 border-b border-gray-100 bg-gray-50 px-5 py-3 text-sm">
						<span class="flex-1 truncate text-right font-semibold">{tm.home.name}</span>
						<span class="rounded-md bg-white px-2 py-0.5 font-display font-extrabold tabular-nums ring-1 ring-gray-200">{tm.home.score} – {tm.away.score}</span>
						<span class="flex-1 truncate font-semibold">{tm.away.name}</span>
					</div>
					<p class="-mt-px border-b border-gray-100 bg-gray-50 pb-2 text-center text-[11px] tracking-wider text-gray-500 uppercase">{teamTargetLabel(tm)}</p>
				{/if}

				{#each SIDES as side, i (side)}
					<div class="flex items-center gap-4 px-5 py-5 {i ? 'border-t border-gray-100' : ''}" class:opacity-50={lost(match, side)}>
						<div class="flex shrink-0 -space-x-3">
							{#each match[side].players as p (p.id)}<Avatar player={p} />{/each}
						</div>
						<div class="min-w-0 flex-1">
							<div class="flex items-center gap-2">
								<span class="truncate font-display text-xl font-extrabold text-gray-950">{match[side].name}</span>
								{#if match.status === 'live' && match.breaking_side === side}
									<span class="flex shrink-0 items-center gap-1 rounded-full bg-gold-100 px-2 py-0.5 text-[11px] font-semibold text-gold-700">
										<span class="h-1.5 w-1.5 rounded-full bg-gold-400"></span>{t('score.breaks')}
									</span>
								{/if}
								{#if match.winner_side === side}<span class="shrink-0 text-gold-500" title={t('score.winner')}>🏆</span>{/if}
							</div>
							{#if match[side].players.length > 1 || (match[side].players[0] && match[side].players[0].display_name !== match[side].name)}
								<div class="truncate text-sm text-gray-500">{match[side].players.map((p) => p.display_name).join(' · ')}</div>
							{/if}
							{#if dots}
								<div class="mt-2 flex flex-wrap gap-1">
									{#each Array(match.target) as _, k (k)}
										<span class="h-2 w-2 rounded-full {k < match[side].score ? 'bg-gray-900' : 'bg-gray-200'}"></span>
									{/each}
								</div>
							{/if}
						</div>
						{#key match[side].score}
							<span class="score font-display font-extrabold text-gray-950 tabular-nums">{match[side].score}</span>
						{/key}
					</div>
				{/each}
			</section>

			{#if match.tournament?.public_token}
				<a href="/t/{match.tournament.public_token}" class="card mt-4 flex items-center gap-3 px-5 py-4 transition hover:border-gray-400">
					<span class="min-w-0 flex-1">
						<span class="eyebrow block">{t('public.seeTournament')}</span>
						<span class="block truncate font-semibold text-gray-900">{match.tournament.name}</span>
					</span>
					<span class="text-xl text-gray-400" aria-hidden="true">→</span>
				</a>
			{/if}
		</div>
	{:else}
		<p class="text-gray-500">{t('common.loading')}</p>
	{/if}
</Shell>

<style>
	.score {
		font-size: clamp(2.75rem, 12vw, 4.5rem);
		line-height: 1;
		animation: pop 0.35s ease-out;
	}
	@keyframes pop {
		from {
			transform: translateY(-6px);
			opacity: 0.4;
		}
	}
</style>
