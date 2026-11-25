<script lang="ts">
	import { api, photoUrl } from '#lib/api.ts';
	import { errorMessage } from '#lib/format.ts';
	import { t } from '#lib/i18n/index.svelte.ts';
	import type { Sponsor } from '#lib/types.ts';

	const ACCEPT = 'image/png,image/jpeg,image/webp';

	let sponsors = $state<Sponsor[]>([]);
	let error = $state('');
	/** Row that just saved, to flash a tick next to it */
	let savedId = $state<number | null>(null);
	let savedTimer: ReturnType<typeof setTimeout> | undefined;

	let draft = $state({ name: '', email: '', file: null as File | null });
	let preview = $state<string | null>(null);
	let dragging = $state(false);
	let adding = $state(false);
	let fileInput = $state<HTMLInputElement>();
	let nameInput = $state<HTMLInputElement>();

	$effect(() => {
		api<Sponsor[]>('/sponsors').then((list) => (sponsors = list));
	});

	// Object URL for the picked logo, freed when it changes
	$effect(() => {
		const file = draft.file;
		if (!file) return void (preview = null);
		const url = URL.createObjectURL(file);
		preview = url;
		return () => URL.revokeObjectURL(url);
	});

	/** Every sponsor endpoint answers with the whole list */
	async function call(path: string, method: string, body: unknown, id?: number) {
		error = '';
		try {
			sponsors = await api<Sponsor[]>(path, { method, body });
			if (id !== undefined) {
				savedId = id;
				clearTimeout(savedTimer);
				savedTimer = setTimeout(() => (savedId = null), 1400);
			}
			return true;
		} catch (e) {
			error = errorMessage(e);
			return false;
		}
	}

	function form(file: File | null, fields: Record<string, string> = {}) {
		const f = new FormData();
		if (file) f.append('logo', file);
		for (const [k, v] of Object.entries(fields)) f.append(k, v);
		return f;
	}

	const isImage = (f: File | null | undefined): f is File => !!f && ACCEPT.split(',').includes(f.type);

	/** Saves one text field on blur; reverts the input if the server refuses it */
	async function saveField(s: Sponsor, key: 'name' | 'email', input: HTMLInputElement) {
		const value = input.value.trim();
		const before = s[key] ?? '';
		if (value === before) return;
		if (key === 'name' && !value) return void (input.value = before);
		if (!input.checkValidity()) {
			error = input.validationMessage;
			input.value = before;
			return;
		}
		if (!(await call(`/sponsors/${s.id}`, 'PATCH', { [key]: value }, s.id))) input.value = before;
	}

	function replaceLogo(s: Sponsor, e: Event) {
		const input = e.currentTarget as HTMLInputElement;
		const file = input.files?.[0];
		input.value = '';
		if (isImage(file)) call(`/sponsors/${s.id}`, 'PATCH', form(file), s.id);
	}

	function move(i: number, by: number) {
		const ids = sponsors.map((s) => s.id);
		[ids[i], ids[i + by]] = [ids[i + by], ids[i]];
		call('/sponsors/order', 'PUT', { ids });
	}

	function remove(s: Sponsor) {
		if (confirm(t('common.confirmRemove', { name: s.name }))) call(`/sponsors/${s.id}`, 'DELETE', undefined);
	}

	function pick(file: File | null | undefined) {
		if (!file) return;
		if (!isImage(file)) return void (error = t('settings.logoWrongType'));
		error = '';
		draft.file = file;
		nameInput?.focus();
		// Suggest the file's name as the sponsor's when none was typed yet
		if (!draft.name.trim()) draft.name = file.name.replace(/\.[^.]+$/, '').replace(/[-_]+/g, ' ').trim();
	}

	function onDrop(e: DragEvent) {
		e.preventDefault();
		dragging = false;
		pick(e.dataTransfer?.files[0]);
	}

	async function add(e: SubmitEvent) {
		e.preventDefault();
		if (!draft.file || !draft.name.trim() || adding) return;
		adding = true;
		const ok = await call('/sponsors', 'POST', form(draft.file, { name: draft.name.trim(), email: draft.email.trim() }));
		adding = false;
		if (ok) {
			draft = { name: '', email: '', file: null };
			if (fileInput) fileInput.value = '';
		}
	}
</script>

<div class="mb-3 flex items-baseline justify-between gap-3">
	<h3 class="text-sm font-semibold">{t('settings.sponsors')}</h3>
	{#if sponsors.length}
		<span class="text-xs text-gray-400">{t('settings.sponsorsOnAir', { on: sponsors.filter((s) => s.active).length, total: sponsors.length })}</span>
	{/if}
</div>
<p class="mb-4 text-xs text-gray-500">{t('settings.sponsorsHelp')}</p>

{#if error}<p class="alert-error mb-4">{error}</p>{/if}

{#if sponsors.length}
	<ol class="mb-5 overflow-hidden rounded-xl ring-1 ring-gray-200">
		{#each sponsors as s, i (s.id)}
			<li class="group flex items-center gap-3 border-gray-100 bg-white px-3 py-3 not-first:border-t sm:gap-4">
				<span class="w-4 shrink-0 text-center text-xs tabular-nums text-gray-400">{i + 1}</span>

				<label class="logo-preview logo-edit h-12 w-28 cursor-pointer" class:off={!s.active} title={t('settings.replaceLogo')}>
					{#if s.logo_url}
						<img src={photoUrl(s.logo_url)} alt={s.name} class="max-h-8 max-w-[96px] object-contain" />
					{:else}
						<span class="text-[11px] text-white/50">{t('settings.noLogo')}</span>
					{/if}
					<span class="logo-edit-hint">{t('settings.replace')}</span>
					<input type="file" accept={ACCEPT} class="hidden" onchange={(e) => replaceLogo(s, e)} />
				</label>

				<div class="flex min-w-0 flex-1 flex-col">
					<input class="inline-edit -ml-1.5 min-w-0 font-medium" value={s.name} required aria-label={t('common.name')}
						onchange={(e) => saveField(s, 'name', e.currentTarget)}
						onkeydown={(e) => e.key === 'Enter' && e.currentTarget.blur()} />
					<input class="inline-edit -ml-1.5 min-w-0 text-xs text-gray-500" type="email" value={s.email ?? ''}
						placeholder={t('settings.addEmail')} aria-label={t('common.email')}
						onchange={(e) => saveField(s, 'email', e.currentTarget)}
						onkeydown={(e) => e.key === 'Enter' && e.currentTarget.blur()} />
				</div>

				<span class="w-4 shrink-0 text-sm text-gray-400 transition-opacity" class:opacity-0={savedId !== s.id} aria-hidden={savedId !== s.id}>✓</span>

				<label class="flex shrink-0 cursor-pointer items-center gap-2 text-xs text-gray-500">
					<input type="checkbox" class="switch" checked={s.active}
						onchange={(e) => call(`/sponsors/${s.id}`, 'PATCH', { active: e.currentTarget.checked }, s.id)} />
					<span class="hidden w-14 sm:inline">{s.active ? t('settings.onAir') : t('settings.offAir')}</span>
				</label>

				<div class="flex shrink-0 flex-col">
					<button class="row-btn" disabled={i === 0} onclick={() => move(i, -1)} aria-label={t('common.moveUp')}>▲</button>
					<button class="row-btn" disabled={i === sponsors.length - 1} onclick={() => move(i, 1)} aria-label={t('common.moveDown')}>▼</button>
				</div>

				<button class="row-btn remove" onclick={() => remove(s)} aria-label={t('common.remove')} title={t('common.remove')}>✕</button>
			</li>
		{/each}
	</ol>
{:else}
	<p class="mb-5 rounded-xl border border-dashed border-gray-200 px-4 py-6 text-center text-sm text-gray-400">{t('settings.noSponsors')}</p>
{/if}

<form class="rounded-xl bg-gray-50 p-4 ring-1 ring-gray-200" onsubmit={add}>
	<p class="mb-3 text-xs font-semibold tracking-wide text-gray-500 uppercase">{t('settings.newSponsor')}</p>
	<div class="flex flex-col gap-4 sm:flex-row">
		<label class="drop logo-preview h-28 w-full cursor-pointer sm:w-48" class:dragging
			ondragover={(e) => { e.preventDefault(); dragging = true; }}
			ondragleave={() => (dragging = false)}
			ondrop={onDrop}>
			{#if preview}
				<img src={preview} alt="" class="max-h-16 max-w-[160px] object-contain" />
				<span class="logo-edit-hint">{t('settings.replace')}</span>
			{:else}
				<span class="px-3 text-center text-xs leading-relaxed text-white/60">
					<span class="block font-medium text-white/85">{t('settings.chooseLogo')}</span>
					{t('settings.dropLogo')}
				</span>
			{/if}
			<input bind:this={fileInput} type="file" accept={ACCEPT} class="hidden"
				onchange={(e) => pick(e.currentTarget.files?.[0])} />
		</label>

		<div class="flex flex-1 flex-col gap-2">
			<input bind:this={nameInput} class="field" placeholder={t('settings.sponsorNamePh')} bind:value={draft.name} required />
			<input class="field" type="email" placeholder={t('settings.sponsorEmailPh')} bind:value={draft.email} />
			<div class="mt-1 flex flex-wrap items-center justify-between gap-2">
				<span class="text-xs text-gray-400">{t('settings.logoHint')}</span>
				<button class="btn btn-primary btn-sm" disabled={!draft.file || !draft.name.trim() || adding}>
					{adding ? t('settings.adding') : t('settings.addSponsor')}
				</button>
			</div>
		</div>
	</div>
</form>

<style>
	.logo-preview {
		position: relative;
		display: grid;
		place-items: center;
		flex: none;
		overflow: hidden;
		border-radius: 10px;
		background: rgb(13 15 14);
	}
	.logo-preview.off img {
		opacity: 0.35;
		filter: grayscale(1);
	}

	/* "Replace" appears over the logo on hover */
	.logo-edit-hint {
		position: absolute;
		inset: 0;
		display: grid;
		place-items: center;
		background: rgb(0 0 0 / 0.6);
		color: #fff;
		font-size: 0.7rem;
		font-weight: 600;
		letter-spacing: 0.04em;
		opacity: 0;
		transition: opacity 0.15s;
	}
	.logo-preview:hover .logo-edit-hint,
	.logo-preview:focus-within .logo-edit-hint {
		opacity: 1;
	}

	.drop {
		border: 1.5px dashed rgb(255 255 255 / 0.18);
		transition: border-color 0.15s;
	}
	.drop:hover,
	.drop.dragging {
		border-color: rgb(255 255 255 / 0.5);
	}

	.row-btn {
		display: grid;
		place-items: center;
		width: 1.6rem;
		height: 1.1rem;
		border-radius: 0.3rem;
		font-size: 0.55rem;
		color: var(--color-gray-400);
		transition:
			color 0.15s,
			background 0.15s;
	}
	.row-btn:hover:not(:disabled) {
		color: var(--color-gray-900);
		background: var(--color-gray-100);
	}
	.row-btn:disabled {
		opacity: 0.25;
	}
	.row-btn.remove {
		height: 1.6rem;
		font-size: 0.75rem;
	}
	.row-btn.remove:hover {
		color: var(--color-red-600);
		background: var(--color-red-50);
	}

	/* Small on/off switch, neutral until on */
	.switch {
		appearance: none;
		position: relative;
		width: 2rem;
		height: 1.15rem;
		flex: none;
		border-radius: 999px;
		background: var(--color-gray-300);
		cursor: pointer;
		transition: background 0.15s;
	}
	.switch::after {
		content: '';
		position: absolute;
		top: 2px;
		left: 2px;
		width: calc(1.15rem - 4px);
		height: calc(1.15rem - 4px);
		border-radius: 999px;
		background: #fff;
		box-shadow: 0 1px 2px rgb(0 0 0 / 0.2);
		transition: transform 0.15s;
	}
	.switch:checked {
		background: var(--color-gray-900);
	}
	.switch:checked::after {
		transform: translateX(0.85rem);
	}
	.switch:focus-visible {
		outline: 2px solid var(--color-gold-400);
		outline-offset: 2px;
	}
</style>
