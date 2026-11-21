import en from './en.ts';
import ptPT, { type Key } from './pt-PT.ts';

export type { Key };
export const LOCALES = ['pt-PT', 'en'] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = 'pt-PT';

const DICTIONARIES: Record<Locale, Record<Key, string>> = { 'pt-PT': ptPT, en };
const STORAGE_KEY = 'pool-tv.locale';

const isLocale = (value: unknown): value is Locale => LOCALES.includes(value as Locale);

/**
 * The language: ?lang= in the URL (overlays in OBS have no saved choice),
 * then the choice saved on this device, else Portuguese.
 */
function initial(): Locale {
	try {
		const fromUrl = new URLSearchParams(location.search).get('lang');
		if (isLocale(fromUrl)) return fromUrl;
		const saved = localStorage.getItem(STORAGE_KEY);
		if (isLocale(saved)) return saved;
	} catch {
		/* storage unavailable */
	}
	return DEFAULT_LOCALE;
}

class I18n {
	locale = $state<Locale>(initial());

	constructor() {
		document.documentElement.lang = this.locale;
	}

	set(locale: Locale) {
		this.locale = locale;
		document.documentElement.lang = locale;
		try {
			localStorage.setItem(STORAGE_KEY, locale);
		} catch {
			/* the choice lasts for this page only */
		}
	}
}

export const i18n = new I18n();

type Params = Record<string, string | number>;

/** Translated text; reactive in templates and $derived, as it reads i18n.locale */
export function t(key: Key, params?: Params): string {
	const text = DICTIONARIES[i18n.locale][key] ?? ptPT[key] ?? key;
	return params ? text.replace(/\{(\w+)\}/g, (m, name) => (name in params ? String(params[name]) : m)) : text;
}

type PluralKey = Key extends infer K ? (K extends `${infer Base}.one` ? Base : never) : never;

/** Plural text: "{n} jogador" / "{n} jogadores" */
export function tn(key: PluralKey, n: number, params?: Params): string {
	return t(`${key}.${n === 1 ? 'one' : 'other'}` as Key, { n, ...params });
}

/** Lenient lookup for values that come from the server, e.g. t(`format.${x}`) */
export function tk(key: string, params?: Params): string {
	return key in ptPT ? t(key as Key, params) : key;
}
