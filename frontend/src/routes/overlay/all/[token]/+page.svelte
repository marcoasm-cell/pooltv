<!--
  OBS overlay of every table of the account. Add as a Browser Source at 1920x1080 (960x1080 also works).
  Drawn inside the Pool TV frame, like the table overlay; put the camera behind it.
  Layout comes from the account settings, or ?layout=split|grid|sidebar|ticker  &frame=0 (no frame)
  "split" gives each table its own camera window, divided by black bars, with the table
  overlay's scoreboard in each; ?cols=2 forces the number of columns.
  When every match on air has the same public page (e.g. one tournament) a QR code to it is
  shown in a corner; ?qr=0 or the setting turns it off.
-->
<script lang="ts">
	import '#lib/overlay/overlay.css';
	import { page } from '$app/state';
	import { flip } from 'svelte/animate';
	import { api } from '#lib/api.ts';
	import { subscribe } from '#lib/cable.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import Frame from '#lib/overlay/Frame.svelte';
	import QrBadge from '#lib/overlay/QrBadge.svelte';
	import { publicUrl } from '#lib/public/links.ts';
	import Scoreboard from '#lib/overlay/Scoreboard.svelte';
	import { raceLabel, tableView, teamTargetLabel, useClock, winnerName } from '#lib/overlay/state.svelte.ts';
	import type { Branding, OverlayConfig, PoolTable } from '#lib/types.ts';

	const token = $derived(page.params.token!);
	let tables = $state<PoolTable[]>([]);
	let config = $state<OverlayConfig | null>(null);
	let branding = $state<Branding | null>(null);
	let error = $state('');
	const clock = useClock();

	const layout = $derived(page.url.searchParams.get('layout') ?? config?.all_tables_layout ?? 'split');
	const framed = $derived(page.url.searchParams.get('frame') !== '0');
	const shown = $derived(
		tables
			.filter((t) => t.active)
			.map((t) => ({ table: t, view: tableView(t, { ...t.overlay, idle_mode: 'waiting', visible: true }, clock.now) }))
	);
	// Tables playing rubbers of the same team match are grouped under one header
	const groups = $derived.by(() => {
		const out: { key: string; title: string | null; items: typeof shown }[] = [];
		for (const item of shown) {
			const tm = item.table.current_match?.team_match;
			const key = tm && item.view !== 'waiting' ? `f${item.table.current_match!.fixture_id}` : `t${item.table.id}`;
			let group = out.find((g) => g.key === key);
			if (!group) {
				const title = tm && item.view !== 'waiting' ? `${tm.home.name} ${tm.home.score} – ${tm.away.score} ${tm.away.name}` : null;
				out.push((group = { key, title, items: [] }));
			}
			group.items.push(item);
		}
		return out;
	});

	// Split layout: one pane per table. Side by side up to 3 (stacked on a narrow source), then a grid
	let innerWidth = $state(1920);
	const cols = $derived.by(() => {
		const forced = Number(page.url.searchParams.get('cols'));
		if (forced > 0) return forced;
		const n = Math.max(1, shown.length);
		if (innerWidth < 1200) return n <= 2 ? 1 : 2;
		return n <= 3 ? n : Math.ceil(Math.sqrt(n));
	});
	const rows = $derived(Math.max(1, Math.ceil(shown.length / cols)));
	// Cells left over in the last row are filled with the frame colour
	const emptyPanes = $derived(rows * cols - shown.length);

	// Split layout: a team match played on several tables shows its team score once, in a
	// band under the panes, instead of on every pane
	const sharedTeamMatches = $derived.by(() => {
		const byFixture = new Map<number, { count: number; tm: NonNullable<PoolTable['current_match']>['team_match'] }>();
		for (const { table, view } of shown) {
			const m = table.current_match;
			if (!m?.team_match || !m.fixture_id || view === 'waiting') continue;
			const entry = byFixture.get(m.fixture_id) ?? { count: 0, tm: m.team_match };
			entry.count++;
			entry.tm = m.team_match;
			byFixture.set(m.fixture_id, entry);
		}
		return new Map([...byFixture].filter(([, e]) => e.count > 1).map(([id, e]) => [id, e.tm!]));
	});
	const teamBand = $derived(layout === 'split' && sharedTeamMatches.size > 0);

	// Header of the frame: what is being played (names / tournaments of the live matches)
	const meta = $derived(
		[...new Set(shown.filter((x) => x.view !== 'waiting' && x.table.current_match).map((x) => {
			const m = x.table.current_match!;
			return m.name ?? m.tournament?.name ?? '';
		}))]
			.filter(Boolean)
			.join(' · ')
	);

	// One QR code for the page every match on air shares (several tournaments: none)
	const qr = $derived.by(() => {
		if (config?.show_qr === false || page.url.searchParams.get('qr') === '0') return null;
		const urls = new Set(shown.filter((x) => x.view !== 'waiting' && x.table.current_match).map((x) => publicUrl(x.table.current_match!)));
		return urls.size === 1 ? [...urls][0] : null;
	});

	async function load() {
		try {
			const data = await api<{ overlay: OverlayConfig; branding: Branding; tables: PoolTable[] }>(`/overlay/all/${token}`, { auth: false });
			tables = data.tables;
			config = data.overlay;
			branding = data.branding;
			error = '';
		} catch (e) {
			error = (e as Error).message;
		}
	}

	$effect(() => {
		load();
		return subscribe('OverlayChannel', { token }, {
			onConnected: load,
			onMessage: (msg) => {
				// Branding or account settings changed: the layout and the badge may have too
				if (msg.type === 'branding') return load();
				if (msg.type !== 'table') return;
				const i = tables.findIndex((t) => t.id === msg.table.id);
				if (i >= 0) tables[i] = msg.table;
				else load();
			}
		});
	});
</script>

<svelte:head><title>{t('overlay.allTitle')}</title></svelte:head>
<svelte:window bind:innerWidth />

{#snippet content()}
	{#if error}
		<div class="error">{t('overlay.error', { error })}</div>
	{:else if layout === 'split'}
		<div class="split" style:--cols={cols} style:--rows={rows}>
			{#each shown as { table, view } (table.id)}
				{@const m = table.current_match}
				<div class="pane">
					<div class="pane-mask"><div class="pane-hole"></div></div>
					<span class="pane-label">
						{#if view === 'live'}<span class="live-dot"></span>{/if}{table.name}
					</span>
					<div class="pane-stage">
						{#if m && (view === 'live' || view === 'winner')}
							<Scoreboard match={m} {view} tableName={table.name} showMeta={false}
								showTeams={!(m.fixture_id && sharedTeamMatches.has(m.fixture_id))} />
						{:else}
							<div class="pane-wait">
								{table.next_match ? t('common.upNextMatch', { home: table.next_match.home.name, away: table.next_match.away.name }) : t('common.free')}
							</div>
						{/if}
					</div>
				</div>
			{/each}
			{#each Array(emptyPanes) as _, i (i)}
				<div class="pane empty"></div>
			{/each}
		</div>
	{:else if layout === 'ticker'}
		<div class="ticker">
			<div class="track" style:animation-duration="{Math.max(20, shown.length * 8)}s">
				{#each [0, 1] as copy (copy)}
					{#each shown as { table, view } (`${copy}-${table.id}`)}
						{@const m = table.current_match}
						<span class="tick">
							<b>{table.name}</b>
							{#if m && view !== 'waiting'}
								{m.home.name} <em>{m.home.score}–{m.away.score}</em> {m.away.name}
								{#if view === 'winner'}<i>{t('common.final')}</i>{/if}
							{:else}
								<span class="idle">{t('common.free')}</span>
							{/if}
						</span>
					{/each}
				{/each}
			</div>
		</div>
	{:else}
		<div class="board {layout}">
			{#each groups as group (group.key)}
				<section class="group" animate:flip={{ duration: 300 }}>
					{#if group.title}<header>{group.title}</header>{/if}
					{#each group.items as { table, view } (table.id)}
						{@const m = table.current_match}
						<div class="row" class:done={view === 'winner'}>
							<div class="table">{table.name}</div>
							{#if m && view !== 'waiting'}
								<div class="p home" class:win={m.winner_side === 'home'}>
									{#if m.status === 'live' && m.breaking_side === 'home'}<span class="dot"></span>{/if}{m.home.name}
								</div>
								<div class="s">{m.home.score}</div>
								<div class="s">{m.away.score}</div>
								<div class="p" class:win={m.winner_side === 'away'}>
									{m.away.name}{#if m.status === 'live' && m.breaking_side === 'away'}<span class="dot"></span>{/if}
								</div>
								<div class="info">{view === 'winner' ? t('overlay.wonBy', { name: winnerName(m) }) : raceLabel(m)}</div>
							{:else}
								<div class="free">
									{table.next_match ? t('common.upNextMatch', { home: table.next_match.home.name, away: table.next_match.away.name }) : t('common.free')}
								</div>
							{/if}
						</div>
					{/each}
				</section>
			{/each}
		</div>
	{/if}
{/snippet}

{#snippet qrCorner()}
	{#if qr}
		<div class="qr-corner" class:left={layout === 'sidebar'}>{#key qr}<QrBadge url={qr} />{/key}</div>
	{/if}
{/snippet}

{#snippet teamFooter()}
	{#each [...sharedTeamMatches] as [id, tm] (id)}
		<span class="tbar">
			<span class="tteam" style:--team="#1e5aa8">{tm.home.name}</span>
			<b>{tm.home.score}</b>
			<small>{teamTargetLabel(tm)}</small>
			<b>{tm.away.score}</b>
			<span class="tteam" style:--team="#b0302a">{tm.away.name}</span>
		</span>
	{/each}
{/snippet}

{#if framed}
	<Frame {meta} footer={teamBand ? teamFooter : undefined} clip={layout === 'ticker'}
		{branding} showPoolTv={config?.show_pool_tv_logo !== false} sponsorSeconds={config?.sponsor_seconds}>
		<div class="area framed">{@render content()}{@render qrCorner()}</div>
	</Frame>
{:else}
	<div class="area">{@render content()}{@render qrCorner()}</div>
{/if}

<style>
	:global(body) {
		font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
		color: #fff;
	}
	/* Everything is placed within this box: the whole canvas, or the frame's window */
	.area {
		--pad: 40px;
		position: fixed;
		inset: 0;
	}
	.area.framed {
		--pad: 24px;
		position: absolute;
	}
	.qr-corner {
		position: absolute;
		top: var(--pad);
		right: var(--pad);
		z-index: 2;
	}
	.qr-corner.left {
		right: auto;
		left: var(--pad);
	}
	/* Team score in the frame's bottom band (split layout) */
	.tbar {
		display: inline-flex;
		align-items: stretch;
		flex: none;
		min-width: 0;
		border-radius: 10px;
		overflow: hidden;
		background: rgb(255 255 255 / 0.06);
		box-shadow: inset 0 0 0 1px rgb(255 255 255 / 0.1);
		color: #fff;
		font-size: 22px;
		font-weight: 700;
	}
	.tbar .tteam {
		min-width: 150px;
		text-align: center;
		padding: 7px 18px;
		background: var(--team);
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}
	.tbar b {
		padding: 7px 16px;
		font-variant-numeric: tabular-nums;
	}
	.tbar small {
		align-self: center;
		font-size: 13px;
		font-weight: 500;
		opacity: 0.6;
		text-transform: uppercase;
		white-space: nowrap;
	}

	/* ---- Split: one camera window per table, divided by bars of the frame colour ---- */
	.split {
		--gap: var(--edge, 16px);
		position: absolute;
		inset: 0;
		display: grid;
		grid-template-columns: repeat(var(--cols), minmax(0, 1fr));
		grid-template-rows: repeat(var(--rows), minmax(0, 1fr));
		gap: var(--gap);
	}
	.pane {
		position: relative;
		min-width: 0;
		min-height: 0;
	}
	/* Half a bar on every side, square outside and rounded inside: neighbouring panes add
	   up to one solid divider, and the corners match the window's */
	.pane-mask {
		position: absolute;
		inset: calc(var(--gap) / -2);
		overflow: hidden;
		pointer-events: none;
	}
	.pane-hole {
		position: absolute;
		inset: calc(var(--gap) / 2);
		border-radius: var(--radius, 18px);
		box-shadow:
			0 0 0 100vmax var(--frame, rgb(13 15 14)),
			inset 0 0 0 1px rgb(255 255 255 / 0.1);
	}
	.pane.empty {
		margin: calc(var(--gap) / -2);
		background: var(--frame, rgb(13 15 14));
	}
	.pane-label {
		position: absolute;
		top: 14px;
		left: 14px;
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 4px 12px;
		border-radius: 999px;
		background: rgb(8 8 8 / 0.8);
		box-shadow: inset 0 0 0 1px rgb(255 255 255 / 0.1);
		font-family: 'Barlow Condensed', 'Arial Narrow', sans-serif;
		font-size: 20px;
		font-weight: 600;
		letter-spacing: 0.08em;
		text-transform: uppercase;
	}
	.live-dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: #e5484d;
	}
	.pane-stage {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: flex-end;
		justify-content: center;
		padding: 20px;
	}
	.pane-wait {
		max-width: 100%;
		box-sizing: border-box;
		padding: 10px 22px;
		border-radius: 999px;
		background: rgb(8 8 8 / 0.85);
		box-shadow: inset 0 0 0 1px rgb(255 255 255 / 0.08);
		font-size: 18px;
		color: rgb(255 255 255 / 0.75);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.board {
		position: absolute;
		display: flex;
		gap: 12px;
		filter: drop-shadow(0 6px 18px rgb(0 0 0 / 0.45));
	}
	.board.grid {
		inset: auto var(--pad) var(--pad) var(--pad);
		flex-wrap: wrap;
		align-items: flex-end;
		justify-content: center;
	}
	.board.sidebar {
		top: var(--pad);
		right: var(--pad);
		flex-direction: column;
		width: min(640px, calc(100% - 2 * var(--pad)));
	}
	.group {
		border-radius: 14px;
		overflow: hidden;
		box-shadow: inset 0 0 0 1px rgb(255 255 255 / 0.08);
		background: rgb(8 8 8 / 0.92);
		min-width: min(600px, 100%);
	}
	.group header {
		padding: 6px 14px;
		background: #f8c045;
		color: #000;
		font-weight: 800;
		font-size: 18px;
		text-transform: uppercase;
	}
	.row {
		display: grid;
		grid-template-columns: 110px 1fr 46px 46px 1fr;
		grid-template-rows: auto auto;
		align-items: center;
		border-top: 1px solid rgb(255 255 255 / 0.08);
		font-size: 20px;
	}
	.table {
		grid-row: span 2;
		align-self: stretch;
		display: grid;
		place-items: center;
		background: rgb(255 255 255 / 0.08);
		font-weight: 700;
		font-size: 16px;
		text-transform: uppercase;
	}
	.p {
		padding: 8px 12px 0;
		font-weight: 600;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		display: flex;
		align-items: center;
		gap: 8px;
	}
	.p.home {
		justify-content: flex-end;
	}
	.p.win {
		color: #f8c045;
	}
	.s {
		margin-top: 8px;
		text-align: center;
		font-family: 'Manrope', 'Inter', sans-serif;
		font-weight: 800;
		font-size: 24px;
		background: #fff;
		color: #0c100e;
		font-variant-numeric: tabular-nums;
	}
	.info {
		grid-column: 2 / -1;
		padding: 2px 12px 6px;
		text-align: center;
		font-size: 13px;
		opacity: 0.7;
	}
	.free {
		grid-column: 2 / -1;
		grid-row: span 2;
		padding: 14px 12px;
		opacity: 0.6;
		font-size: 17px;
	}
	.row.done .info {
		color: #f8c045;
		opacity: 1;
	}
	.dot {
		width: 10px;
		height: 10px;
		border-radius: 50%;
		background: #f8c045;
		flex: none;
	}
	.ticker {
		position: absolute;
		left: 0;
		right: 0;
		bottom: 0;
		height: 52px;
		overflow: hidden;
		border-top: 2px solid #f8c045;
		background: rgb(8 8 8 / 0.94);
		display: flex;
		align-items: center;
	}
	.track {
		display: flex;
		white-space: nowrap;
		animation: scroll linear infinite;
	}
	.tick {
		padding: 0 36px;
		font-size: 22px;
		border-right: 1px solid rgb(255 255 255 / 0.15);
	}
	.tick b {
		color: #f8c045;
		margin-right: 12px;
		text-transform: uppercase;
	}
	.tick em {
		font-style: normal;
		font-weight: 800;
		padding: 0 10px;
	}
	.tick i {
		margin-left: 10px;
		font-style: normal;
		color: #f8c045;
		font-size: 16px;
		text-transform: uppercase;
	}
	.idle {
		opacity: 0.6;
	}
	@keyframes scroll {
		to {
			transform: translateX(-50%);
		}
	}
	/* Narrow browser sources, e.g. 960x1080 side by side */
	@media (max-width: 1200px) {
		.area {
			--pad: 24px;
		}
		.area.framed {
			--pad: 16px;
		}
		.board.sidebar {
			width: calc(100% - 2 * var(--pad));
		}
		.tbar {
			font-size: 18px;
		}
		.tbar .tteam {
			min-width: 0;
		}
		.tbar .tteam,
		.tbar b {
			padding: 5px 12px;
		}
		.tbar small {
			font-size: 11px;
		}
		.pane-label {
			top: 10px;
			left: 10px;
			font-size: 17px;
		}
		.pane-stage {
			padding: 12px;
		}
		.pane-wait {
			font-size: 15px;
		}
		.board.grid .group {
			flex: 1 1 100%;
		}
		.row {
			grid-template-columns: 84px minmax(0, 1fr) 40px 40px minmax(0, 1fr);
			font-size: 18px;
		}
		.table {
			font-size: 14px;
		}
		.s {
			font-size: 21px;
		}
		.tick {
			padding: 0 24px;
			font-size: 19px;
		}
	}
	.error {
		position: absolute;
		bottom: var(--pad);
		left: var(--pad);
		padding: 12px 24px;
		border-radius: 12px;
		background: #a8281d;
		font-size: 22px;
	}
</style>
