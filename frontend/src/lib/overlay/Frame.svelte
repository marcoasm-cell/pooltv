<!--
  Broadcast frame of the overlays: a header band and a rounded transparent window where the
  camera shows through. Whatever is passed as children is laid out inside the window
  (a positioned box the size of the window).
  Header: Pool TV badge (with pooltv.me) and the club's logo on the left; the sponsors in turn,
  the label and the club's name on the right.
-->
<script lang="ts">
	import type { Snippet } from 'svelte';
	import { cubicIn, cubicOut } from 'svelte/easing';
	import { photoUrl } from '../api.ts';
	import Brand from '../components/Brand.svelte';
	import { t } from '../i18n/index.svelte.ts';
	import type { Branding } from '../types.ts';

	let {
		meta = '',
		label = '',
		status = null,
		clip = false,
		footer,
		branding = null,
		showPoolTv = true,
		sponsorSeconds = 8,
		children
	}: {
		/** Centre of the header, e.g. tournament · round */
		meta?: string;
		/** Right of the header, e.g. the table name */
		label?: string;
		status?: 'final' | 'free' | null;
		/** Clip the content to the window's rounded shape (e.g. a ticker along its edge) */
		clip?: boolean;
		/** A bottom band like the header, full width, e.g. the team score */
		footer?: Snippet;
		/** Club logo and sponsors */
		branding?: Branding | null;
		/** The Pool TV badge (account setting) */
		showPoolTv?: boolean;
		/** How long each sponsor stays up */
		sponsorSeconds?: number;
		children: Snippet;
	} = $props();

	const sponsors = $derived(branding?.sponsors.filter((s) => s.logo_url) ?? []);
	let turn = $state(0);
	const sponsor = $derived(sponsors.length ? sponsors[turn % sponsors.length] : null);
	$effect(() => {
		if (sponsors.length < 2) return;
		const id = setInterval(() => turn++, Math.max(3, Number(sponsorSeconds) || 8) * 1000);
		return () => clearInterval(id);
	});

	/* The next sponsor rises into the cell, coming into focus, once the last has left upwards */
	const rise = (_: Element, { delay = 0, duration = 900 } = {}) => ({
		delay,
		duration,
		easing: cubicOut,
		css: (t: number, u: number) =>
			`opacity: ${t}; transform: translateY(${u * 70}%) scale(${0.9 + t * 0.1}); filter: blur(${u * 8}px);`
	});
	const leave = (_: Element, { duration = 500 } = {}) => ({
		duration,
		easing: cubicIn,
		css: (t: number, u: number) =>
			`opacity: ${t}; transform: translateY(${-u * 60}%) scale(${1 - u * 0.06}); filter: blur(${u * 6}px);`
	});
</script>

<div class="frame" class:has-footer={!!footer} class:has-sponsor={!!sponsor}>
	<div class="window"></div>
	<header>
		<div class="brands">
			{#if showPoolTv}<Brand /><span class="site">pooltv.me</span>{/if}
			{#if branding?.logo_url}
				{#if showPoolTv}<span class="divider"></span>{/if}
				<img class="club" src={photoUrl(branding.logo_url)} alt={branding.name} />
			{/if}
		</div>
		<div class="meta">{meta}</div>
		<div class="status">
			{#if sponsor}
				<div class="sponsors">
					{#key sponsor.id}
						<img src={photoUrl(sponsor.logo_url)} alt={sponsor.name} in:rise={{ delay: 300 }} out:leave />
					{/key}
				</div>
				{#if label || status || branding?.name}<span class="divider"></span>{/if}
			{/if}
			{#if label}<span class="label">{label}</span>{/if}
			{#if status === 'final'}
				<span class="pill">{t('common.final')}</span>
			{:else if status === 'free'}
				<span class="pill idle">{t('common.free')}</span>
			{/if}
			{#if branding?.name}
				{#if label || status}<span class="divider"></span>{/if}
				<span class="account">{branding.name}</span>
			{/if}
		</div>
	</header>
	<div class="area" class:clip>
		{@render children()}
	</div>
	{#if footer}<footer>{@render footer()}</footer>{/if}
</div>

<style>
	.frame {
		--frame: rgb(13 15 14);
		--header: 68px;
		--footer: 68px;
		--edge: 16px;
		--radius: 18px;
		--bottom: var(--edge);
		position: fixed;
		inset: 0;
		overflow: hidden;
		color: #fff;
		font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
	}
	.window,
	.area {
		position: absolute;
		inset: var(--header) var(--edge) var(--bottom);
		border-radius: var(--radius);
	}
	.frame.has-footer {
		--bottom: var(--footer);
	}
	footer {
		position: absolute;
		inset: auto 0 0;
		height: var(--bottom);
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 16px;
		padding: 0 calc(var(--edge) + 6px);
	}
	.window {
		/* Paint everything outside the window with the frame colour */
		box-shadow:
			0 0 0 100vmax var(--frame),
			inset 0 0 0 1px rgb(255 255 255 / 0.1),
			inset 0 0 32px rgb(0 0 0 / 0.25);
	}
	.area.clip {
		overflow: hidden;
	}
	header {
		position: absolute;
		inset: 0 calc(var(--edge) + 6px) auto;
		height: var(--header);
		display: flex;
		align-items: center;
		justify-content: space-between;
	}
	/* Centred on the whole width, whatever the sides hold */
	.meta {
		position: absolute;
		left: 50%;
		transform: translateX(-50%);
		max-width: 50%;
		text-align: center;
		font-size: 17px;
		font-weight: 500;
		color: rgb(255 255 255 / 0.6);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.status,
	.brands {
		display: flex;
		align-items: center;
		gap: 14px;
		min-width: 0;
	}
	.divider {
		width: 1px;
		height: 28px;
		background: rgb(255 255 255 / 0.16);
		flex: none;
	}
	/* Logos sit on the dark frame as they are: transparent PNGs look best */
	.club {
		height: 44px;
		max-width: 220px;
		object-fit: contain;
	}
	/* Sponsors take turns in one cell: the old one leaves upwards, the next rises in */
	.sponsors {
		display: grid;
		overflow: hidden;
		/* Room for the blur, so the edges don't cut it */
		padding: 6px 0;
		margin: -6px 0;
		box-sizing: content-box;
		align-items: center;
		justify-items: end;
		height: 40px;
		width: 180px;
	}
	.sponsors img {
		grid-area: 1 / 1;
		max-height: 40px;
		max-width: 180px;
		object-fit: contain;
		will-change: transform, opacity, filter;
	}
	.label {
		font-family: 'Barlow Condensed', 'Arial Narrow', sans-serif;
		font-size: 24px;
		font-weight: 600;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: rgb(255 255 255 / 0.85);
		white-space: nowrap;
	}
	.site {
		margin-left: -4px;
		font-size: 15px;
		font-weight: 600;
		letter-spacing: 0.02em;
		color: rgb(255 255 255 / 0.55);
		white-space: nowrap;
	}
	/* The account (club) name, in the top right corner */
	.account {
		min-width: 0;
		max-width: 320px;
		font-family: 'Barlow Condensed', 'Arial Narrow', sans-serif;
		font-size: 20px;
		font-weight: 500;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: rgb(255 255 255 / 0.6);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.pill {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 4px 12px;
		border-radius: 999px;
		box-shadow: inset 0 0 0 1px rgb(255 255 255 / 0.16);
		font-size: 13px;
		font-weight: 700;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		color: #f8c045;
		white-space: nowrap;
	}
	.pill.idle {
		color: rgb(255 255 255 / 0.55);
	}

	/* Narrow browser sources, e.g. two overlays side by side at 960x1080 */
	@media (max-width: 1200px) {
		.frame {
			--header: 56px;
			--footer: 56px;
			--edge: 10px;
			--radius: 14px;
		}
		.meta {
			font-size: 14px;
		}
		/* Leave the sides room for the sponsor */
		.has-sponsor .meta {
			max-width: 34%;
		}
		.status,
		.brands {
			gap: 10px;
		}
		.club {
			height: 34px;
			max-width: 140px;
		}
		.sponsors {
			height: 30px;
			width: 110px;
		}
		.sponsors img {
			max-height: 30px;
			max-width: 110px;
		}
		.divider {
			height: 22px;
		}
		.label {
			font-size: 20px;
		}
		.site {
			font-size: 12px;
		}
		.account {
			max-width: 160px;
			font-size: 16px;
		}
		.pill {
			padding: 3px 10px;
			font-size: 11px;
		}
	}
</style>
