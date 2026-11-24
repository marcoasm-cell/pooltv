<!--
  OBS overlay of one table. Add as a Browser Source at 1920x1080, or 960x1080 for two side by side.
  It draws a frame (Pool TV header + a rounded window); put the camera behind it so the game shows
  through the window.
  Query options: ?position=top|bottom  &scale=1.2  &frame=0 (scoreboard only, no frame)
  &qr=0 (no QR code to the public page; also a setting)
-->
<script lang="ts">
	import '#lib/overlay/overlay.css';
	import { page } from '$app/state';
	import { api } from '#lib/api.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import { subscribe } from '#lib/cable.ts';
	import Frame from '#lib/overlay/Frame.svelte';
	import QrBadge from '#lib/overlay/QrBadge.svelte';
	import { publicUrl } from '#lib/public/links.ts';
	import Scoreboard from '#lib/overlay/Scoreboard.svelte';
	import { matchCaption, tableView, useClock } from '#lib/overlay/state.svelte.ts';
	import type { Branding, PoolTable } from '#lib/types.ts';

	const token = $derived(page.params.token!);
	const position = $derived(page.url.searchParams.get('position') === 'top' ? 'top' : 'bottom');
	const scale = $derived(Number(page.url.searchParams.get('scale')) || 1);
	const framed = $derived(page.url.searchParams.get('frame') !== '0');

	let table = $state<PoolTable | null>(null);
	let branding = $state<Branding | null>(null);
	let error = $state('');
	const clock = useClock();
	const view = $derived(table ? tableView(table, table.overlay, clock.now) : 'hidden');
	// The operator switched this table's overlay off: hide the frame too
	const switchedOff = $derived(table?.overlay.visible === false || table?.overlay.visible === 'false');

	const match = $derived(view === 'live' || view === 'winner' ? table?.current_match : null);
	const meta = $derived(match ? matchCaption(match) : '');
	// QR code to the match's public page (or its tournament's), in the corner away from the scoreboard
	const qr = $derived(
		match && table?.overlay.show_qr !== false && page.url.searchParams.get('qr') !== '0' ? publicUrl(match) : null
	);

	async function load() {
		try {
			const data = await api<{ table: PoolTable; branding: Branding }>(`/overlay/tables/${token}`, { auth: false });
			table = data.table;
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
				if (msg.type === 'table') table = msg.table;
				else if (msg.type === 'branding') branding = msg.branding;
			}
		});
	});
</script>

<svelte:head><title>{t('overlay.title', { name: table?.name ?? t('overlay.table') })}</title></svelte:head>

{#snippet qrCorner()}
	{#if qr}
		<div class="qr-corner {position === 'top' ? 'bottom' : 'top'}" style:--scale={scale}>
			{#key qr}<QrBadge url={qr} />{/key}
		</div>
	{/if}
{/snippet}

{#snippet content()}
	{#if error}
		<!-- Only visible in the OBS preview while the link is wrong -->
		<div class="error">{t('overlay.error', { error })}</div>
	{:else if table && match}
		<Scoreboard {match} view={view as 'live' | 'winner'} tableName={table.name} showMeta={!framed} />
	{:else if table && view === 'waiting'}
		<div class="waiting">
			<strong>{table.name}</strong>
			{#if table.next_match}
				<span>{t('common.upNextMatch', { home: table.next_match.home.name, away: table.next_match.away.name })}</span>
			{:else}
				<span>{t('overlay.waiting')}</span>
			{/if}
		</div>
	{/if}
{/snippet}

{#if framed && table && !switchedOff}
	<Frame {meta} label={table.name} status={view === 'live' ? null : view === 'winner' ? 'final' : 'free'}
		{branding} showPoolTv={table.overlay.show_pool_tv_logo !== false} sponsorSeconds={table.overlay.sponsor_seconds}>
		<div class="stage in-frame {position}" style:--scale={scale}>
			{@render content()}
		</div>
		<div class="corner-box in-frame">{@render qrCorner()}</div>
	</Frame>
{:else}
	<div class="stage {position}" style:--scale={scale}>
		{@render content()}
	</div>
	<div class="corner-box">{@render qrCorner()}</div>
{/if}

<style>
	/* ---- Scoreboard stage ---- */
	.stage {
		position: fixed;
		inset: 0;
		display: flex;
		justify-content: center;
		padding: 40px;
	}
	/* Inside the frame the scoreboard sits as a lower third within the window */
	.stage.in-frame {
		position: absolute;
		padding: 28px;
	}
	.stage.bottom {
		align-items: flex-end;
	}
	.stage.top {
		align-items: flex-start;
	}
	.stage > :global(*) {
		transform: scale(var(--scale));
		transform-origin: center bottom;
	}
	.stage.top > :global(*) {
		transform-origin: center top;
	}
	/* ---- QR code, in the top or bottom right corner ---- */
	.corner-box {
		position: fixed;
		inset: 0;
		pointer-events: none;
	}
	.corner-box.in-frame {
		position: absolute;
	}
	.qr-corner {
		position: absolute;
		right: 40px;
		transform: scale(var(--scale));
	}
	.in-frame .qr-corner {
		right: 28px;
	}
	.qr-corner.top {
		top: 40px;
		transform-origin: right top;
	}
	.in-frame .qr-corner.top {
		top: 28px;
	}
	.qr-corner.bottom {
		bottom: 40px;
		transform-origin: right bottom;
	}
	.in-frame .qr-corner.bottom {
		bottom: 28px;
	}
	.waiting,
	.error {
		display: flex;
		gap: 16px;
		align-items: center;
		padding: 12px 28px;
		border-radius: 999px;
		background: rgb(8 8 8 / 0.88);
		box-shadow: inset 0 0 0 1px rgb(255 255 255 / 0.08);
		color: #fff;
		font: 500 22px 'Inter', 'Segoe UI', system-ui, sans-serif;
		max-width: 100%;
		box-sizing: border-box;
	}
	.waiting span {
		min-width: 0;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.waiting strong {
		color: #f8c045;
		flex: none;
	}
	.error {
		background: #a8281d;
	}

	/* Narrow browser sources, e.g. two overlays side by side at 960x1080 */
	@media (max-width: 1200px) {
		.stage {
			padding: 24px;
		}
		.qr-corner,
		.in-frame .qr-corner {
			right: 16px;
		}
		.qr-corner.top,
		.in-frame .qr-corner.top {
			top: 16px;
		}
		.qr-corner.bottom,
		.in-frame .qr-corner.bottom {
			bottom: 16px;
		}
		.stage.in-frame {
			padding: 16px;
		}
		.waiting,
		.error {
			gap: 12px;
			padding: 10px 20px;
			font-size: 18px;
		}
	}
</style>
