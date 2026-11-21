<script lang="ts" module>
	// Who made the app: change it here, and in the meta tags in src/app.html.
	export const CREATOR = 'Marco Marques';
</script>

<script lang="ts">
	import { t } from '#lib/i18n/index.svelte.ts';

	let { tone = 'light', class: cls = '' }: { tone?: 'light' | 'dark'; class?: string } = $props();
</script>

<p class="text-xs {tone === 'dark' ? 'text-white/40' : 'text-gray-400'} {cls}">
	© {new Date().getFullYear()} Pool TV · {t('credit.madeBy')}
	<span class="font-medium {tone === 'dark' ? 'text-white/60' : 'text-gray-500'}">{CREATOR}</span>
</p>
