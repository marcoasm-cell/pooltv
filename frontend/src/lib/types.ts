export type Side = 'home' | 'away';

/** A round of a tournament, named by the client in its language */
export interface RoundName {
	key: 'final' | 'semi_final' | 'quarter_final' | 'round' | 'winners_final' | 'losers_round' | 'grand_final' | 'grand_final_reset' | 'friendly';
	round: number;
}

export interface Player {
	id: number;
	name: string;
	nickname: string | null;
	display_name: string;
	country_code: string | null;
	fpb_license: number | null;
	fpb_club: string | null;
	/** Path on the API of a square photo; use with photoUrl() */
	photo_url: string | null;
}

export interface Team {
	id: number;
	name: string;
	display_name: string;
	fpb_code: string | null;
	fpb_club: string | null;
	roster?: (Player & { captain: boolean })[];
}

/** Federação Portuguesa de Bilhar data, read live from portalbilhar.pt */
export interface FpbTeam {
	code: string;
	name: string;
	club: string | null;
	status: string | null;
	district: string | null;
	team_id: number | null;
}

export interface FpbAthlete {
	license: number;
	name: string;
	full_name: string | null;
	club: string | null;
	district: string | null;
	player_id: number | null;
}

export interface FpbImportResult {
	players_created: number;
	players_updated: number;
	teams_created: number;
	teams_updated: number;
	roster_added: number;
	photos_queued: number;
}

export interface GameType {
	id: number;
	key: string;
	name: string;
	scoring_mode: 'racks' | 'points';
	default_target: number;
	break_rule: 'alternate' | 'winner' | 'loser';
	rules_url: string | null;
	built_in: boolean;
}

export interface MatchSide {
	name: string;
	score: number;
	players: Player[];
}

export interface TeamSide {
	name: string | null;
	score: number;
}

export interface Match {
	id: number;
	/** Optional name given when creating a match outside any tournament */
	name: string | null;
	status: 'scheduled' | 'live' | 'finished';
	kind: 'singles' | 'doubles';
	target: number;
	rubber_number: number | null;
	breaking_side: Side | null;
	winner_side: Side | null;
	started_at: string | null;
	finished_at: string | null;
	pool_table_id: number | null;
	queue_position: number | null;
	game_type: { key: string; name: string; scoring_mode: 'racks' | 'points' };
	home: MatchSide;
	away: MatchSide;
	fixture_id: number | null;
	tournament: { id: number; name: string; kind: string; format: string } | null;
	round_label: RoundName | null;
	team_match: {
		win_condition: 'rubbers' | 'racks';
		target: number | null;
		rubbers: number;
		home: TeamSide;
		away: TeamSide;
	} | null;
}

export interface OverlayConfig {
	idle_mode: 'hidden' | 'waiting';
	winner_banner_seconds: number;
	all_tables_layout: 'split' | 'grid' | 'sidebar' | 'ticker';
	show_pool_tv_logo: boolean;
	sponsor_seconds: number;
	visible?: boolean | string;
}

export interface Sponsor {
	id: number;
	name: string;
	logo_url: string | null;
	/** Only for admins (the overlays only get the active ones) */
	active?: boolean;
	position?: number;
}

/** What the overlays show around the scores: the club and its sponsors */
export interface Branding {
	name: string;
	logo_url: string | null;
	sponsors: Sponsor[];
}

export interface PoolTable {
	id: number;
	name: string;
	position: number;
	active: boolean;
	overlay: OverlayConfig;
	overlay_token?: string;
	current_match: Match | null;
	next_match: Match | null;
	queue?: Match[];
}

export interface Entry {
	id: number;
	seed: number | null;
	name: string;
	display_name: string;
	player: Player | null;
	team: Team | null;
	/** Standalone team match: positions and bench for substitutions */
	lineup: {
		slots: { starter: Player; current: Player }[];
		bench: (Player & { starter_slot: number | null; reserve: boolean })[];
	} | null;
}

export interface Fixture {
	id: number;
	tournament_id: number;
	bracket: 'winners' | 'losers' | 'grand_final' | 'group';
	round: number;
	position: number;
	status: 'pending' | 'ready' | 'live' | 'finished' | 'void';
	home_score: number;
	away_score: number;
	home_bye: boolean;
	away_bye: boolean;
	round_label: RoundName;
	home: Entry | null;
	away: Entry | null;
	winner_entry_id: number | null;
	matches?: Match[];
}

export interface StandingRow {
	entry: Entry;
	played: number;
	won: number;
	drawn: number;
	lost: number;
	score_for: number;
	score_against: number;
	points: number;
}

export interface Tournament {
	id: number;
	name: string;
	kind: 'individual' | 'team';
	format: 'single_elimination' | 'double_elimination' | 'round_robin' | 'friendly';
	target: number;
	status: 'draft' | 'running' | 'finished';
	starts_on: string | null;
	grand_final_reset: boolean;
	team_match_format: ('singles' | 'doubles')[];
	team_win_condition: 'rubbers' | 'racks';
	team_target: number | null;
	ended_early: boolean;
	/** Tables the matches are dealt to automatically, in the order picked */
	pool_table_ids: number[];
	game_type: GameType;
	entries_count: number;
	entries?: Entry[];
	fixtures?: Fixture[];
	winner?: Entry | null;
	standings?: StandingRow[];
}

export interface User {
	id: number;
	name: string;
	email: string;
	role: 'owner' | 'scorer';
	/** Platform admin: manages every account */
	admin: boolean;
	/** The user's own account (a platform admin may be looking at another one) */
	account_id: number;
}

/** An account as platform admins see it in the list of accounts */
export interface AdminAccount {
	id: number;
	name: string;
	users_count: number;
	owners: { id: number; name: string; email: string }[];
	created_at: string;
}

export interface Account {
	id: number;
	name: string;
	logo_url?: string | null;
	overlay_settings?: OverlayConfig;
	overlay_token?: string | null;
}
