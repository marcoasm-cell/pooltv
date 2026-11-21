import type { Account, User } from './types.ts';

const KEY = 'pool-tv.session';

interface Stored {
	token: string;
	user: User;
	account: Account;
}

function load(): Stored | null {
	try {
		return JSON.parse(localStorage.getItem(KEY) ?? 'null');
	} catch {
		return null;
	}
}

class Session {
	#data = $state<Stored | null>(load());
	// Derived, so effects that read the token only re-run when it really
	// changes: refreshing the user and account (set() with the same token) must
	// not restart the live connection or fetch /me again in a loop
	#token = $derived(this.#data?.token ?? null);

	get token() {
		return this.#token;
	}
	get user() {
		return this.#data?.user ?? null;
	}
	get account() {
		return this.#data?.account ?? null;
	}
	/** Platform admin: manages every account */
	get isAdmin() {
		return this.user?.admin === true;
	}
	/** Can configure the club: its owners, and platform admins */
	get canManage() {
		return this.isAdmin || this.user?.role === 'owner';
	}
	/** A platform admin looking at another club than their own */
	get isVisiting() {
		return this.isAdmin && !!this.account && this.account.id !== this.user?.account_id;
	}

	set(data: Stored) {
		this.#data = data;
		try {
			localStorage.setItem(KEY, JSON.stringify(data));
		} catch {
			/* storage unavailable: session lasts for this page only */
		}
	}

	clear() {
		this.#data = null;
		try {
			localStorage.removeItem(KEY);
		} catch {
			/* ignore */
		}
	}
}

export const session = new Session();
