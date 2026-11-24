<!--
  Broadcast frame of the overlays: a header band and a rounded transparent window where the
  camera shows through. Whatever is passed as children is laid out inside the window
  (a positioned box the size of the window).
  Header: Pool TV badge (with pooltv.me) and the club's logo on the left; the sponsors (cards with
  logo, name and email, as many side by side as fit, in turns when there are more), the label and
  the club's name on the right.
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

	// As many cards as fit in what the header leaves them: its width less the brands, the label
	// and club name, and some room for the centre text (sizes as in the CSS below)
	let innerWidth = $state(1920);
	let headerWidth = $state(0);
	let brandsWidth = $state(0);
	let tailWidth = $state(0);
	const size = $derived(
		innerWidth <= 1200 ? { card: 190, gap: 8, space: 10, meta: 140 } : { card: 240, gap: 12, space: 18, meta: 320 }
	);
	const room = $derived(
		headerWidth - brandsWidth - tailWidth - (meta ? size.meta : 0) - size.space * (tailWidth ? 4 : 2)
	);
	const slots = $derived(Math.max(1, Math.min(sponsors.length, Math.floor((room + size.gap) / (size.card + size.gap)))));
	const rotating = $derived(sponsors.length > slots);

	// More sponsors than cards: they take turns, a card's worth at a time, wrapping round
	let turn = $state(0);
	const shown = $derived(
		Array.from({ length: sponsors.length ? slots : 0 }, (_, i) => sponsors[(turn * slots + i) % sponsors.length])
	);
	$effect(() => {
		if (!rotating) return;
		const id = setInterval(() => turn++, Math.max(3, Number(sponsorSeconds) || 8) * 1000);
		return () => clearInterval(id);
	});

	/* The next sponsors rise into their cells, one after another, coming into focus, once the last has left upwards */
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

<svelte:window bind:innerWidth />

<div class="frame" class:has-footer={!!footer} class:has-sponsor={sponsors.length > 0}>
	<div class="window"></div>
	<header bind:clientWidth={headerWidth}>
		<div class="brands" bind:clientWidth={brandsWidth}>
			{#if showPoolTv}<Brand /><span class="site">pooltv.me</span>{/if}
			{#if branding?.logo_url}
				{#if showPoolTv}<span class="divider"></span>{/if}
				<img class="club" src={photoUrl(branding.logo_url)} alt={branding.name} />
			{/if}
		</div>
		<div class="meta">{meta}</div>
		<div class="status">
			{#if sponsors.length}
				<div class="sponsors">
					{#each shown as sponsor, i (i)}
						<div class="cell">
							{#key rotating ? `${turn}:${sponsor.id}` : sponsor.id}
								<div class="sponsor" in:rise={{ delay: 300 + i * 120 }} out:leave>
									<span class="logo"><img src={photoUrl(sponsor.logo_url)} alt="" /></span>
									<span class="who">
										<span class="name">{sponsor.name}</span>
										{#if sponsor.email}<span class="email">{sponsor.email}</span>{/if}
									</span>
								</div>
							{/key}
						</div>
					{/each}
				</div>
				{#if label || status || branding?.name}<span class="divider"></span>{/if}
			{/if}
			{#if label || status || branding?.name}
				<div class="tail" bind:clientWidth={tailWidth}>
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
		--header: 104px;
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
		gap: 18px;
	}
	/* Centred in what the sides leave */
	.meta {
		flex: 1 1 0;
		min-width: 0;
		text-align: center;
		font-size: 20px;
		font-weight: 500;
		color: rgb(255 255 255 / 0.6);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.status,
	.brands,
	.tail {
		display: flex;
		align-items: center;
		gap: 18px;
		flex: none;
	}
	.divider {
		width: 1px;
		height: 36px;
		background: rgb(255 255 255 / 0.16);
		flex: none;
	}
	/* The Pool TV badge, sized to the taller header */
	.brands > :global(img:first-child) {
		width: 60px;
		height: 60px;
	}
	/* Logos sit on the dark frame as they are: transparent PNGs look best */
	.club {
		height: 58px;
		max-width: 260px;
		object-fit: contain;
	}
	/* The sponsors: a row of cards, as many as the script finds room for */
	.sponsors {
		display: flex;
		gap: 12px;
		overflow: hidden;
		/* Room for the blur, so the edges don't cut it */
		padding: 8px 0;
		margin: -8px 0;
	}
	/* One card's place: the old card leaves upwards, the next rises in */
	.cell {
		flex: none;
		display: grid;
		width: 240px;
		height: 68px;
	}
	.sponsor {
		grid-area: 1 / 1;
		display: flex;
		align-items: center;
		gap: 12px;
		min-width: 0;
		box-sizing: border-box;
		overflow: hidden;
		padding: 6px 14px 6px 6px;
		border-radius: 14px;
		background: linear-gradient(180deg, rgb(255 255 255 / 0.07), rgb(255 255 255 / 0.03));
		box-shadow:
			inset 0 0 0 1px rgb(255 255 255 / 0.1),
			inset 0 1px 0 rgb(255 255 255 / 0.06);
		will-change: transform, opacity, filter;
	}
	/* A light tile, so dark and light logos both read */
	.sponsor .logo {
		flex: none;
		display: grid;
		place-items: center;
		width: 84px;
		height: 56px;
		padding: 6px 10px;
		box-sizing: border-box;
		border-radius: 10px;
		overflow: hidden;
		background: rgb(255 255 255 / 0.94);
	}
	/* Fills the tile and is scaled down inside it, never past it */
	.sponsor .logo img {
		display: block;
		width: 100%;
		height: 100%;
		min-width: 0;
		min-height: 0;
		object-fit: contain;
	}
	.who {
		display: flex;
		flex-direction: column;
		gap: 3px;
		min-width: 0;
	}
	.who .name {
		font-size: 18px;
		font-weight: 700;
		line-height: 1.15;
		color: #fff;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.who .email {
		font-size: 13px;
		font-weight: 500;
		letter-spacing: 0.01em;
		color: rgb(255 255 255 / 0.55);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.label {
		font-family: 'Barlow Condensed', 'Arial Narrow', sans-serif;
		font-size: 28px;
		font-weight: 600;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: rgb(255 255 255 / 0.85);
		white-space: nowrap;
	}
	.site {
		margin-left: -4px;
		font-size: 17px;
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
		font-size: 24px;
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
			--header: 80px;
			--footer: 56px;
			--edge: 10px;
			--radius: 14px;
		}
		.meta {
			font-size: 14px;
		}
		header,
		.status,
		.brands,
		.tail {
			gap: 10px;
		}
		.brands > :global(img:first-child) {
			width: 46px;
			height: 46px;
		}
		.club {
			height: 42px;
			max-width: 150px;
		}
		.sponsors {
			gap: 8px;
		}
		.cell {
			width: 190px;
			height: 54px;
		}
		.sponsor {
			gap: 10px;
			padding: 5px 12px 5px 5px;
			border-radius: 12px;
		}
		.sponsor .logo {
			width: 64px;
			height: 44px;
			padding: 5px 7px;
			border-radius: 8px;
		}
		.who .name {
			font-size: 16px;
		}
		.who .email {
			font-size: 12px;
		}
		.divider {
			height: 28px;
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
