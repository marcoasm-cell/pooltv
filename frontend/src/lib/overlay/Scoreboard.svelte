<!-- Lower-third scoreboard of one table: team bar, players, score, break -->
<script lang="ts">
	import { fly, fade } from 'svelte/transition';
	import { t } from '../i18n/index.svelte.ts';
	import type { Match } from '../types.ts';
	import { matchCaption, raceLabel, teamTargetLabel, winnerName } from './state.svelte.ts';

	let {
		match,
		view,
		tableName,
		showMeta = true,
		showTeams = true
	}: {
		match: Match;
		view: 'live' | 'winner';
		tableName: string;
		showMeta?: boolean;
		/** Off when the team score is already shown elsewhere (split overlay header) */
		showTeams?: boolean;
	} = $props();

	const tm = $derived(match.team_match);
	const meta = $derived(matchCaption(match, tableName));
</script>

<div class="board" in:fly={{ y: 60, duration: 450 }} out:fade={{ duration: 300 }}>
	{#if view === 'winner'}
		<div class="banner" in:fly={{ y: 20, duration: 400 }}>{t('overlay.winner', { name: winnerName(match) })}</div>
	{/if}

	{#if tm && showTeams}
		<div class="teams">
			<span class="team" style:--team="#1e5aa8">{tm.home.name}</span>
			<span class="team-score">{tm.home.score}</span>
			<span class="team-sep">{teamTargetLabel(tm)}</span>
			<span class="team-score">{tm.away.score}</span>
			<span class="team" style:--team="#b0302a">{tm.away.name}</span>
		</div>
	{/if}

	<div class="main">
		<div class="name home" class:winner={match.winner_side === 'home'}>
			{#if match.status === 'live'}<span class="break" class:on={match.breaking_side === 'home'}></span>{/if}
			<span class="txt">{match.home.name}</span>
		</div>
		{#key match.home.score}<div class="score" in:fly={{ y: -18, duration: 250 }}>{match.home.score}</div>{/key}
		<div class="race">
			<span>{raceLabel(match)}</span>
			<small>{match.game_type.name}</small>
		</div>
		{#key match.away.score}<div class="score" in:fly={{ y: -18, duration: 250 }}>{match.away.score}</div>{/key}
		<div class="name away" class:winner={match.winner_side === 'away'}>
			<span class="txt">{match.away.name}</span>
			{#if match.status === 'live'}<span class="break" class:on={match.breaking_side === 'away'}></span>{/if}
		</div>
	</div>

	{#if view !== 'winner' && meta && showMeta}
		<div class="meta">{meta}</div>
	{/if}
</div>

<style>
	.board {
		display: flex;
		flex-direction: column;
		align-items: center;
		font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
		color: #fff;
		/* 1170px on a full 1920 canvas, shrinks to the space it is given (e.g. 960x1080 side by side) */
		width: min(1170px, 100%);
		/* The sizes below follow the room the board gets, not the canvas */
		container-type: inline-size;
		filter: drop-shadow(0 8px 24px rgb(0 0 0 / 0.45));
	}
	.teams {
		display: flex;
		align-items: stretch;
		background: rgb(8 8 8 / 0.94);
		border-radius: 10px 10px 0 0;
		overflow: hidden;
		max-width: 100%;
		font-weight: 700;
		font-size: 22px;
	}
	.team {
		padding: 6px 18px;
		background: var(--team);
		text-transform: uppercase;
		letter-spacing: 0.04em;
		min-width: 150px;
		text-align: center;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.team-score {
		padding: 6px 16px;
		font-variant-numeric: tabular-nums;
	}
	.team-sep {
		align-self: center;
		white-space: nowrap;
		font-size: 13px;
		font-weight: 500;
		opacity: 0.6;
		text-transform: uppercase;
	}
	.main {
		display: grid;
		width: 100%;
		box-sizing: border-box;
		grid-template-columns: minmax(0, 1fr) 90px 150px 90px minmax(0, 1fr);
		align-items: stretch;
		height: 76px;
		border-radius: 14px;
		overflow: hidden;
		box-shadow:
			inset 0 0 0 1px rgb(255 255 255 / 0.08),
			inset 0 2px 0 #f8c045;
		background: rgb(8 8 8 / 0.94);
	}
	.name {
		min-width: 0;
		display: flex;
		align-items: center;
		gap: 14px;
		padding: 0 24px;
		font-size: 30px;
		font-weight: 700;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	/* Long names end in an ellipsis instead of overflowing the panel */
	.txt {
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.name.home {
		justify-content: flex-end;
		background: linear-gradient(90deg, transparent, rgb(30 90 168 / 0.4));
	}
	.name.away {
		background: linear-gradient(270deg, transparent, rgb(176 48 42 / 0.4));
	}
	.name.winner {
		color: #f8c045;
	}
	.score {
		display: grid;
		place-items: center;
		font-family: 'Manrope', 'Inter', sans-serif;
		font-size: 46px;
		font-weight: 800;
		font-variant-numeric: tabular-nums;
		background: #fff;
		color: #0c100e;
	}
	.race {
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		background: #f8c045;
		color: #000;
		font-size: 16px;
		font-weight: 700;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		line-height: 1.25;
	}
	.race small {
		font-size: 13px;
		font-weight: 500;
		opacity: 0.85;
		text-transform: none;
	}
	.break {
		width: 14px;
		height: 14px;
		border-radius: 50%;
		background: rgb(255 255 255 / 0.15);
		flex: none;
	}
	.break.on {
		background: #f8c045;
		box-shadow: 0 0 10px #f8c045;
	}
	.meta,
	.banner {
		margin-top: 8px;
		padding: 5px 20px;
		border-radius: 999px;
		background: rgb(8 8 8 / 0.88);
		font-size: 17px;
		font-weight: 500;
		max-width: 100%;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		box-sizing: border-box;
	}
	.banner {
		margin-top: 0;
		margin-bottom: 8px;
		background: #f8c045;
		color: #0c100e;
		font-size: 22px;
		font-weight: 800;
		text-transform: uppercase;
		letter-spacing: 0.08em;
	}

	/* Less room: a 960x1080 source, or a pane of the split all-tables overlay */
	@container (max-width: 1000px) {
		.teams {
			font-size: 18px;
		}
		.team {
			min-width: 0;
			padding: 5px 12px;
		}
		.team-score {
			padding: 5px 12px;
		}
		.team-sep {
			font-size: 11px;
		}
		.main {
			grid-template-columns: minmax(0, 1fr) 68px 112px 68px minmax(0, 1fr);
			height: 64px;
			border-radius: 12px;
		}
		.name {
			gap: 10px;
			padding: 0 14px;
			font-size: 24px;
		}
		.score {
			font-size: 38px;
		}
		.race {
			font-size: 13px;
			letter-spacing: 0.04em;
		}
		.race small {
			font-size: 11px;
		}
		.break {
			width: 11px;
			height: 11px;
		}
		.meta {
			font-size: 15px;
			padding: 4px 16px;
		}
		.banner {
			font-size: 18px;
		}
	}
	/* Small panes, e.g. 3 or more tables side by side */
	@container (max-width: 640px) {
		.teams {
			font-size: 15px;
		}
		.team,
		.team-score {
			padding: 4px 10px;
		}
		.main {
			grid-template-columns: minmax(0, 1fr) 50px 84px 50px minmax(0, 1fr);
			height: 52px;
			border-radius: 10px;
		}
		.name {
			gap: 8px;
			padding: 0 10px;
			font-size: 18px;
		}
		.score {
			font-size: 30px;
		}
		.race {
			font-size: 11px;
			letter-spacing: 0.02em;
		}
		.race small {
			font-size: 10px;
		}
		.break {
			width: 9px;
			height: 9px;
		}
		.meta {
			font-size: 13px;
		}
		.banner {
			font-size: 15px;
			padding: 4px 14px;
		}
	}
</style>
