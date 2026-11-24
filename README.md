# Pool TV

Pool games and tournaments: run them from the web app, score them on a tablet at
the table (Android app), and show the live score on stream with OBS overlays.

```
backend/    Rails 8 API + Action Cable (live updates), PostgreSQL
frontend/   SvelteKit SPA: admin, scoring screen, OBS overlays
android/    (next) Capacitor wrapper around frontend/build
```

The app is always online: the server holds every score, and each tap on the
scoring screen goes straight to the API. When the connection drops, a red
banner appears and scoring stops until the connection is back.

## Running it

```sh
# Backend (Ruby 3.4.2, PostgreSQL)
cd backend
bundle install
bin/rails db:prepare          # creates pool_tv_development and seeds the game types
bin/rails server -p 3000

# Frontend (Node 22)
cd frontend
npm install
cp .env.example .env          # VITE_API_URL / VITE_CABLE_URL point at the backend
npm run dev
```

Sign in as a platform admin (`admin@example.com` / `password` in development), create the club in *Accounts*, add its tables and players.

Tests: `cd backend && bin/rails test`. Type check: `cd frontend && npm run check`.

## Concepts

| Concept | Meaning |
|---|---|
| **Account** | A club or venue. Everything belongs to one account. |
| **Pool table** | A physical table. Each one has its own OBS link and a *current match*. |
| **Game type** | Portuguese Pool, 8-Ball, 9-Ball, 10-Ball, Blackball, Straight Pool, One-Pocket, Bank Pool (built-in), plus custom ones per account. Scored by **racks** (race to N) or **points** (first to N, fouls take points off). Each game type has a break rule: alternate, winner breaks or loser breaks. |
| **Tournament** | Individual (player vs player) or team (team vs team). Formats: single elimination, double elimination (with an optional grand-final reset), round robin, or a friendly (a single team match or game). |
| **Fixture** | One pairing in a tournament: entry vs entry. Byes resolve as walkovers. |
| **Match** | One game on one table. A fixture has one match, or one match per **rubber** in a team match. Quick matches have no tournament. |
| **Team match** | A list of rubbers (singles/doubles). The captain picks the lineup from the team roster. A team wins on most rubbers (optionally stopping once one team reaches N) or on most racks over all rubbers. A tie in an elimination round waits for a decider rubber. |

## OBS overlays

In *Tables & OBS*, every table has a link, and there is one link for all tables. In OBS, add a
**Browser Source**, paste the link and set it to 1920×1080. The page is transparent.

- `/overlay/table/<token>`: scoreboard of whatever is played on that table: players, score,
  race, who breaks, the team score for rubbers, and a winner banner at the end.
  Options: `?position=top`, `?scale=1.2`.
- `/overlay/all/<token>`: every table. `?layout=grid|sidebar|ticker`, or set the default in Settings.
- Overlays are in Portuguese (pt-PT); add `?lang=en` to the link for English.

In Settings → *Branding and sponsors* you upload the club's logo (shown next to the Pool TV badge,
which can be switched off) and the sponsors' logos, which take turns on the right of the header
(every 8 seconds by default). Use PNGs with a transparent background; they sit on the dark frame.
Changes reach open overlays straight away. The `?frame=0` overlays have no header, so no logos.

The links never change unless you press *New link*, which turns the old one off.
In Settings you choose what an idle table shows (nothing, or "waiting / up next")
and how long the winner banner stays up.

## Public pages (QR code)

Every match and tournament has a public page anyone can follow live on their phone, no sign-in:

- `/m/<token>`: one match: players, score, who breaks, race; a rubber also shows the team score.
- `/t/<token>`: a tournament: the tree (single/double elimination), or the standings and the
  drawn fixtures round by round (round robin); plus the matches on now and up next.

The overlays show a QR code to the page (the tournament's when the match belongs to one) in the
corner away from the scoreboard; the all-tables overlay shows one only when every match on air
shares the same page. Turn it off in Settings, or with `?qr=0` on the link. The scoring screen has
a QR button that shows it full screen for people around the table. The QR codes use this site's
address; set `VITE_PUBLIC_URL` for the Android app.

## Import from the FPB

Admins can copy teams, rosters and athletes from the Federação Portuguesa de Bilhar
portal (portalbilhar.pt) in *Teams* or *Players* → *Import from the FPB*: pick a discipline
and a competition and tick the teams, or search athletes by name, licence or club.

- The data is copied into the account. Only the import screen reads the portal live;
  tournaments, scoring and overlays never depend on it.
- Players are matched by FPB licence, teams by FPB code (`EQP7605`); records created by
  hand with the same name are linked instead of copied.
- *Sync everything* imports again: names are updated and new roster players added.
  Nothing is removed, and nicknames, colours, short names and captains are kept.
- Athletes' photos are downloaded by a background job (`FpbPhotosJob`) into Active Storage
  and served as 256×256 squares at a signed link (`photo_url`). A photo is downloaded again only
  when its file on the portal changes. In production the job needs a Solid Queue worker
  (`SOLID_QUEUE_IN_PUMA=1` or `bin/jobs`).
- The FPB has no official API. `app/services/fpb/client.rb` reads the JSON method behind
  the public athletes list and parses the public team pages; if the portal changes, the
  tests in `test/services/fpb_test.rb` (on saved pages) show what the parser expects.

## Users

- **Owner / admin**: set everything up.
- **Scorer**: can only score. Use a scorer account on the tablet at each table: *Live* → *Score*.

## API

JSON under `/api`, with a bearer token from `POST /api/login` or `POST /api/signup`. Live updates
come over Action Cable at `/cable`:

- `OverlayChannel` with `{ token }`: public, used by the overlays.
- `AccountChannel`: requires `?token=<session token>` on the cable URL. Carries all account changes.

Messages are complete snapshots (`{type: "table" | "match" | "fixture", ...}`). Clients replace
what they hold and reload on reconnect, so they never miss a change.

See `backend/config/routes.rb` for the full list of routes.
