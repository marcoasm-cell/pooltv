<script lang="ts">
	import { onMount } from 'svelte';
	import { photoUrl } from '#lib/api.ts';
	import { i18n, t } from '#lib/i18n/index.svelte.ts';
	import { HEIGHT, WIDTH, imageFromBlob, loadFonts, loadImage, render } from '#lib/thumbnail/render.ts';
	import { accountSettings } from '../account.svelte.ts';

	const settings = accountSettings();
	const s = settings.state;

	const LIMITS = { title: 80, subtitle: 100, tag: 24 };
	const DRAFT_KEY = 'pool-tv.thumbnail';
	const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp'];

	type Draft = { title: string; subtitle: string; tag: string; live: boolean; showClub: boolean; showPoolTv: boolean };
	const blank: Draft = { title: '', subtitle: '', tag: '', live: false, showClub: true, showPoolTv: true };

	// The text stays on this device between visits (not the image)
	function readDraft(): Draft {
		try {
			return { ...blank, ...JSON.parse(localStorage.getItem(DRAFT_KEY) ?? '{}') };
		} catch {
			return { ...blank };
		}
	}
	const form = $state<Draft>(readDraft());
	$effect(() => {
		const json = JSON.stringify(form);
		try {
			localStorage.setItem(DRAFT_KEY, json);
		} catch {
			/* storage unavailable */
		}
	});

	let canvas = $state<HTMLCanvasElement>();
	let fontsReady = $state(false);
	let poolTv = $state<HTMLImageElement | null>(null);
	let club = $state<HTMLImageElement | null>(null);
	let background = $state<HTMLImageElement | null>(null);
	let backgroundName = $state('');
	let dragging = $state(false);
	let imageError = $state('');
	let copied = $state(false);
	let busy = $state(false);
	let titleInput = $state<HTMLInputElement>();

	onMount(() => {
		settings.load();
		loadFonts().then(() => (fontsReady = true));
		loadImage('/logo.png').then((img) => (poolTv = img));
		titleInput?.focus();
	});

	const logoUrl = $derived(s.account?.logo_url);
	$effect(() => {
		const url = photoUrl(logoUrl);
		club = null;
		loadImage(url).then((img) => (club = img));
	});

	const canCopy = typeof ClipboardItem !== 'undefined' && !!navigator.clipboard?.write;
	const hasTitle = $derived(form.title.trim().length > 0);

	// Redrawn on every change
	$effect(() => {
		if (!canvas) return;
		void fontsReady;
		render(
			canvas,
			{
				title: form.title,
				subtitle: form.subtitle,
				tag: form.tag,
				clubName: s.account?.name ?? '',
				live: form.live,
				placeholder: t('thumb.placeholder'),
				liveLabel: t('thumb.live'),
				locale: i18n.locale
			},
			{
				poolTv: form.showPoolTv ? poolTv : null,
				club: form.showClub ? club : null,
				background
			}
		);
	});

	async function setBackground(file: File | undefined) {
		imageError = '';
		if (!file) return;
		if (!IMAGE_TYPES.includes(file.type)) {
			imageError = t('thumb.imageWrongType');
			return;
		}
		const img = await imageFromBlob(file);
		if (!img) {
			imageError = t('thumb.imageWrongType');
			return;
		}
		if (background) URL.revokeObjectURL(background.src);
		background = img;
		backgroundName = file.name;
	}

	function removeBackground() {
		if (background) URL.revokeObjectURL(background.src);
		background = null;
		backgroundName = '';
	}

	function onDrop(e: DragEvent) {
		e.preventDefault();
		dragging = false;
		setBackground(e.dataTransfer?.files[0]);
	}

	const toBlob = () => new Promise<Blob | null>((resolve) => canvas!.toBlob(resolve, 'image/png'));

	/** A file name from the title, e.g. grande-final-do-open.png */
	const fileName = $derived(
		(form.title
			.replaceAll('*', '')
			.normalize('NFD')
			.replace(/[̀-ͯ]/g, '')
			.toLowerCase()
			.replace(/[^a-z0-9]+/g, '-')
			.replace(/^-|-$/g, '')
			.slice(0, 60) || 'thumbnail') + '.png'
	);

	async function download() {
		if (!hasTitle || !canvas) return;
		busy = true;
		const blob = await toBlob();
		busy = false;
		if (!blob) return;
		const a = document.createElement('a');
		a.href = URL.createObjectURL(blob);
		a.download = fileName;
		a.click();
		setTimeout(() => URL.revokeObjectURL(a.href), 1000);
	}

	async function copy() {
		if (!hasTitle || !canvas) return;
		try {
			await navigator.clipboard.write([new ClipboardItem({ 'image/png': toBlob().then((b) => b!) })]);
			copied = true;
			setTimeout(() => (copied = false), 1600);
		} catch {
			/* clipboard refused */
		}
	}

	function reset() {
		Object.assign(form, { ...blank });
		removeBackground();
		titleInput?.focus();
	}

	function onKeydown(e: KeyboardEvent) {
		if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') download();
	}
</script>

<svelte:window onkeydown={onKeydown} />

<header class="mb-8">
	<p class="eyebrow mb-1">{t('settings.title')}</p>
	<h1 class="page-title">{t('thumb.title')}</h1>
	<p class="mt-2 max-w-2xl text-sm text-gray-500">{t('thumb.help')}</p>
</header>
{#if s.error}<p class="alert-error mb-4">{s.error}</p>{/if}

<div class="grid items-start gap-6 lg:grid-cols-[minmax(0,380px)_minmax(0,1fr)]">
	<!-- The form -->
	<form class="card order-2 divide-y divide-gray-100 lg:order-1" onsubmit={(e) => { e.preventDefault(); download(); }}>
		<fieldset class="space-y-4 p-6">
			<legend class="sr-only">{t('thumb.text')}</legend>
			<h2 class="section-title">{t('thumb.text')}</h2>

			<div>
				<div class="flex items-baseline justify-between">
					<label class="lbl" for="thumb-title">{t('thumb.heading')}</label>
					<span class="counter" class:near={form.title.length > LIMITS.title - 10}>{form.title.length}/{LIMITS.title}</span>
				</div>
				<input id="thumb-title" class="field mt-1.5" bind:this={titleInput} bind:value={form.title}
					maxlength={LIMITS.title} placeholder={t('thumb.headingPh')} autocomplete="off" required />
				<p class="hint">{t('thumb.headingHint')}</p>
			</div>

			<div>
				<div class="flex items-baseline justify-between">
					<label class="lbl" for="thumb-subtitle">{t('thumb.subtitle')} <span class="opt">· {t('thumb.optional')}</span></label>
					<span class="counter" class:near={form.subtitle.length > LIMITS.subtitle - 10}>{form.subtitle.length}/{LIMITS.subtitle}</span>
				</div>
				<input id="thumb-subtitle" class="field mt-1.5" bind:value={form.subtitle}
					maxlength={LIMITS.subtitle} placeholder={t('thumb.subtitlePh')} autocomplete="off" />
			</div>

			<div>
				<label class="lbl" for="thumb-tag">{t('thumb.tag')} <span class="opt">· {t('thumb.optional')}</span></label>
				<input id="thumb-tag" class="field mt-1.5" bind:value={form.tag}
					maxlength={LIMITS.tag} placeholder={t('thumb.tagPh')} autocomplete="off" />
				<p class="hint">{t('thumb.tagHint')}</p>
			</div>
		</fieldset>

		<fieldset class="space-y-3 p-6">
			<legend class="sr-only">{t('thumb.background')}</legend>
			<h2 class="section-title">{t('thumb.background')} <span class="opt">· {t('thumb.optional')}</span></h2>
			{#if background}
				<div class="flex items-center gap-3 rounded-xl border border-gray-200 p-2">
					<img src={background.src} alt="" class="h-12 w-20 flex-none rounded-lg object-cover" />
					<span class="min-w-0 flex-1 truncate text-sm text-gray-700">{backgroundName}</span>
					<label class="btn btn-ghost btn-sm">
						{t('settings.replace')}
						<input type="file" accept={IMAGE_TYPES.join(',')} class="hidden" onchange={(e) => setBackground(e.currentTarget.files?.[0])} />
					</label>
					<button type="button" class="link-danger pr-1" onclick={removeBackground}>{t('common.remove')}</button>
				</div>
			{:else}
				<label class="dropzone" class:dragging
					ondragover={(e) => { e.preventDefault(); dragging = true; }}
					ondragleave={() => (dragging = false)}
					ondrop={onDrop}>
					<span class="btn btn-ghost btn-sm">{t('thumb.chooseImage')}</span>
					<span class="text-xs text-gray-500">{t('thumb.dropImage')}</span>
					<input type="file" accept={IMAGE_TYPES.join(',')} class="hidden" onchange={(e) => setBackground(e.currentTarget.files?.[0])} />
				</label>
			{/if}
			{#if imageError}<p class="text-xs text-red-600">{imageError}</p>{:else}<p class="hint">{t('thumb.imageHint')}</p>{/if}
		</fieldset>

		<fieldset class="space-y-3 p-6">
			<legend class="sr-only">{t('thumb.options')}</legend>
			<h2 class="section-title">{t('thumb.options')}</h2>
			<label class="flex items-center gap-2.5 text-sm"><input type="checkbox" bind:checked={form.live} />{t('thumb.showLive')}</label>
			{#if logoUrl}
				<label class="flex items-center gap-2.5 text-sm"><input type="checkbox" bind:checked={form.showClub} />{t('thumb.showClub')}</label>
			{/if}
			<label class="flex items-center gap-2.5 text-sm"><input type="checkbox" bind:checked={form.showPoolTv} />{t('thumb.showPoolTv')}</label>
		</fieldset>

		<div class="flex items-center justify-between gap-3 p-6 lg:hidden">
			<button type="button" class="text-sm text-gray-500 hover:text-gray-900" onclick={reset}>{t('thumb.reset')}</button>
			<button type="submit" class="btn btn-primary" disabled={!hasTitle || busy}>{t('thumb.download')}</button>
		</div>
	</form>

	<!-- The preview: the canvas itself, so what you see is what you download -->
	<section class="order-1 lg:sticky lg:top-24 lg:order-2">
		<div class="card overflow-hidden">
			<div class="flex items-center justify-between border-b border-gray-100 px-5 py-3">
				<h2 class="section-title">{t('thumb.preview')}</h2>
				<span class="font-condensed text-sm font-semibold tracking-wider text-gray-400">{WIDTH} × {HEIGHT} · PNG</span>
			</div>
			<div class="bg-gray-50 p-4 sm:p-5">
				<canvas bind:this={canvas} width={WIDTH} height={HEIGHT}
					class="block aspect-video w-full rounded-lg shadow-[0_12px_32px_-12px_rgb(0_0_0/0.45)]"
					aria-label={t('thumb.preview')}></canvas>
			</div>
			<div class="flex flex-wrap items-center gap-3 border-t border-gray-100 px-5 py-4">
				<button type="button" class="btn btn-primary" disabled={!hasTitle || busy} onclick={download}>{t('thumb.download')}</button>
				{#if canCopy}
					<button type="button" class="btn btn-ghost" disabled={!hasTitle} onclick={copy}>{copied ? t('thumb.copied') : t('thumb.copy')}</button>
				{/if}
				<button type="button" class="ml-auto text-sm text-gray-500 transition hover:text-gray-900" onclick={reset}>{t('thumb.reset')}</button>
				{#if !hasTitle}<p class="w-full text-xs text-gray-500">{t('thumb.needTitle')}</p>{/if}
			</div>
		</div>
	</section>
</div>

<style lang="postcss">
	@reference "../../../../app.css";

	.section-title {
		@apply font-condensed text-sm font-semibold tracking-[0.14em] text-gray-500 uppercase;
	}
	.opt {
		@apply font-normal text-gray-400 normal-case tracking-normal;
	}
	.counter {
		@apply text-xs text-gray-400 tabular-nums;
	}
	.counter.near {
		@apply text-gold-600;
	}
	.hint {
		@apply mt-1.5 text-xs text-gray-500;
	}
	.dropzone {
		@apply flex cursor-pointer flex-col items-center gap-2 rounded-xl border-2 border-dashed border-gray-200 px-4 py-6 text-center transition-colors hover:border-gray-300;
	}
	.dropzone.dragging {
		@apply border-gold-400 bg-gold-100/40;
	}
</style>
