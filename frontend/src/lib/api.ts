import { i18n, t } from './i18n/index.svelte.ts';
import { session } from './session.svelte.ts';

export const API_URL: string = import.meta.env.VITE_API_URL ?? 'http://localhost:3003';

/** Full URL of a file served by the API, such as a player's photo */
export const photoUrl = (path: string | null | undefined) => (path ? `${API_URL}${path}` : null);

export class ApiError extends Error {
	constructor(
		message: string,
		public status: number
	) {
		super(message);
	}
}

export async function api<T = unknown>(
	path: string,
	options: { method?: string; body?: unknown; auth?: boolean } = {}
): Promise<T> {
	// The server answers errors in the same language as the app
	const headers: Record<string, string> = { Accept: 'application/json', 'Accept-Language': i18n.locale };
	// FormData (file uploads) goes as multipart; the browser sets its Content-Type
	const form = options.body instanceof FormData;
	if (options.body !== undefined && !form) headers['Content-Type'] = 'application/json';
	if (options.auth !== false && session.token) headers.Authorization = `Bearer ${session.token}`;

	let res: Response;
	try {
		res = await fetch(`${API_URL}/api${path}`, {
			method: options.method ?? (options.body !== undefined ? 'POST' : 'GET'),
			headers,
			body: form ? (options.body as FormData) : options.body !== undefined ? JSON.stringify(options.body) : undefined
		});
	} catch {
		throw new ApiError(t('errors.network'), 0);
	}

	if (res.status === 401 && options.auth !== false) session.clear();
	if (res.status === 204) return undefined as T;

	const data = await res.json().catch(() => ({}));
	if (!res.ok) throw new ApiError(data.error ?? t('errors.requestFailed', { status: res.status }), res.status);
	return data as T;
}
