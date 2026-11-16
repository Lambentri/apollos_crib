
# ApollosCrib

<!-- gg:badges ci workflow:audit workflow:credo workflow:android license package:fdroid:io.neiam.apolloscrib -->
[![CI status](https://gg.neiam.co/r/neiam/apollos_crib/badge/ci.svg)](https://gg.neiam.co/r/neiam/apollos_crib/actions) [![audit status](https://gg.neiam.co/r/neiam/apollos_crib/badge/workflow/audit.svg)](https://gg.neiam.co/r/neiam/apollos_crib/actions) [![credo status](https://gg.neiam.co/r/neiam/apollos_crib/badge/workflow/credo.svg)](https://gg.neiam.co/r/neiam/apollos_crib/actions) [![android status](https://gg.neiam.co/r/neiam/apollos_crib/badge/workflow/android.svg)](https://gg.neiam.co/r/neiam/apollos_crib/actions) [![license](https://gg.neiam.co/r/neiam/apollos_crib/badge/license.svg)](https://gg.neiam.co/r/neiam/apollos_crib/blob/master/LICENSE) [![install io.neiam.apolloscrib (fdroid)](https://gg.neiam.co/r/neiam/apollos_crib/badge/package/fdroid/io.neiam.apolloscrib.svg)](https://gg.neiam.co/r/neiam/apollos_crib/packages)
<!-- /gg:badges -->

A generalized automated data collection platform, for the purpose of collecting and displaying timely data for wherever you may be.

It supports the creation of offerings data from 8+ generalized sources, with more to come:

- GTFS (+RT)
- GBFS (+EBikes/FreeBikes)
- iCal
- Tidal
- Ephem
- AirNow
- OpenWeather
- Cronos
- Gitlab
- Package Tracking
- Webhooks

These can be formed into reusable Queries that can be grouped into Visions.
Visions are interpreted by the Pythiae who forward them to clients via Ankyra.
Foci are anchors for querying in physical space
Plani can be configured to provide the equivalent to an unanchored Foci updated via Ankyra 

## Clients

Ankyra clients subscribe to a rabbit user's MQTT topic and draw whatever the
Pythiae publishes to it.

- [`clients/lilygo4.7`](clients/lilygo4.7) — a LilyGo 4.7" e-paper panel, MicroPython
- [`clients/android`](clients/android) — a [Smartspacer](https://github.com/KieronQuinn/Smartspacer)
  plugin putting a vision on the Android home and lock screen

[`apollos-types`](https://github.com/neiam/apollos-types) is the source of truth
for the published wire format.

## Public Demo

The public demo instance https://ac.gmp.io/ is here, and the landing data displays queries for various entities around 
- Assembly Row, Somerville
- Union Square, NYC
- Mission, SF
- Lincoln Park, Chicago


## Sign in with NEIAM

Optional OpenID Connect sign-in through Authelia at `auth.neiam.org`, using
[`neiam_auth`](https://gg.neiam.co/neiam/neiam_auth) (`v0.2.0`, pinned in
`apps/room_sanctum/mix.exs`). It's off unless `OIDC_ENABLED=true`: until then
there's no button and every `/auth/oidc/*` route except `/auth/oidc/health` is
a 404. Password login stays as it is. The glue is
`apps/room_sanctum/lib/room_sanctum/neiam_auth_adapter.ex`.

**Settings** (env, read at start; the values from the `apollos-crib` deployment):

| Variable | Value |
|---|---|
| `OIDC_ISSUER` | `https://auth.neiam.org` |
| `OIDC_CLIENT_ID` | `apollos-crib` |
| `OIDC_CLIENT_SECRET` | from the `apollos-crib-oidc` Secret (optional: without it the provider is off) |
| `OIDC_REDIRECT_URI` | `https://ac.neiam.org/auth/oidc/neiam/callback` |
| `OIDC_SCOPES` | `openid profile email groups` |
| `OIDC_GROUPS_CLAIM` | `groups` |
| `OIDC_TRUST_EMAIL` | `true` |
| `OIDC_REQUIRED_FOR_LINKED` | `true` |
| `OIDC_PROVISION` | `invite_only` |
| `OIDC_PROVISION_GROUPS` | `admins` |
| `OIDC_LABEL` | `Sign in with NEIAM` |
| `OIDC_LOGOUT_URL` | `https://auth.neiam.org/logout` |
| `OIDC_ENABLED` | `true` |

Routes: `/auth/oidc/neiam/login`, `/auth/oidc/neiam/callback` and
`/auth/oidc/health` (JSON: enabled, and each provider's status).

**Who gets in.** Invite-only. On a first sign-in:

- A verified email that matches an existing account links to it. Every
  account can be linked.
- Members of `admins` get a new, passwordless, confirmed account.
- Anyone else is refused and told to ask for an invite; no account is made.
- A signed-in user can link their account from `/users/settings`.

Groups aren't mapped to roles: admins still come from `CRIB_ADMIN_EMAILS`,
which SSO leaves alone. The groups are recorded on the identity row. The
public kiosk, board and map pages (`/p/...`) stay public with SSO on: they
render signed out and never start a sign-in.

**Once linked.** Apollos Crib doesn't act on `REQUIRED_FOR_LINKED` yet: a
linked account can still sign in with its password. To remove a link anyway:

```sh
kubectl -n apollos-crib exec deploy/apollos-crib -- bin/apollos_crib rpc 'NeiamAuth.unlink(<user id>)'
```

**Turning it off.** Remove `OIDC_ENABLED`, or delete the `apollos-crib-oidc`
Secret, and restart the pods.

**Doctor.** Checks TLS, discovery, JWKS and the client credentials from
inside the pod, whether or not SSO is on:

```sh
kubectl -n apollos-crib exec deploy/apollos-crib -- bin/apollos_crib rpc 'NeiamAuth.Doctor.check()'
```

### Development

Debian/Ubuntu users may need to install `erlang-xmerl`

Postgres is expected on **port 54321** (not 5432) as `postgres`/`postgres`, database
`room_sanctum_dev` — see `config/dev.exs`. `docker-compose.yml` brings one up.

Maps draw from CARTO unless a tile server is configured — see
[CUSTOM_MAPS.md](CUSTOM_MAPS.md).

#### First-time setup

```sh
mix deps.get
mix download_data     # REQUIRED — see below, the server will not boot without it
```

Then run the migrations, then `mix phx.server`. Two endpoints come up:

- `room_hermes` on http://localhost:4001
- `room_sanctum` on http://localhost:4002

#### `mix download_data` — required before the first boot

`wheretz` (timezone lookup by coordinate) ships **without** its geojson database, and
`WhereTZ.Application.start/2` loads that data unconditionally at boot. If it is missing,
the app fails to start and takes the whole umbrella down with it:

```
** (Mix) Could not start application wheretz: exited in: WhereTZ.Application.start(:normal, [])
    ** (EXIT) an exception was raised:
        ** (MatchError) no match of right hand side value:
    {:error, :enoent}
            (wheretz 0.1.16) lib/mix/tasks/download_data.ex:52: Mix.Tasks.DownloadData.load_from_json/0
```

`mix download_data` fetches a 42MB archive from the `timezone-boundary-builder` GitHub
release and unpacks it to ~174MB. Gotchas:

- The data lands in **`_build/$MIX_ENV/lib/wheretz/priv/data/`**, not in `deps/`. So it is
  per-environment (run it again under `MIX_ENV=prod`) and anything that clears `_build`
  — `mix clean`, a fresh clone, a Docker layer rebuild — means running it again.
- **Boot is slow.** wheretz reparses the 139MB geojson into Mnesia on *every* start, so
  expect several minutes before the endpoints bind. It is not hung.
- Startup writes a Mnesia directory (`Mnesia.nonode@nohost/`) into the repo root. It is
  not currently in `.gitignore`.

#### Migrations

Migrations need to be run from within the `room_sanctum`/`room_hermes` directories in that order.

Until they are run the server *will* start and bind both ports, but every request returns
**503** and the log fills with `Postgrex.Error ... (undefined_table)` for `oban_jobs`,
`cfg_sources`, `cfg_visions`, `keryxiae`, and friends. A 503 on a fresh checkout means
migrations, not a broken build.

Both apps share one database, and therefore one `schema_migrations` table. So
`mix ecto.migrations` run from either directory reports the *other* app's migrations as
`** FILE NOT FOUND **` — they are recorded in the shared table but their files live under
the sibling app. That is expected, not a corrupt migration history.

#### Once it is up

- `room_sanctum` (http://localhost:4002) serves the UI and should return 200.
- `room_hermes` (http://localhost:4001) has no root route — its `get "/"` is commented out
  in the router — so **404 on `/` is normal** and means the app is healthy.

#### Bundled imports

`apps/room_sanctum/priv/imports/` holds ready-made source bundles for the
**Import Offerings** page (Offerings → Import). Paste a file's contents into the
box, check the ten green cards, and hit *Import Valid Sources*.

- [`france_top_ten.json`](apps/room_sanctum/priv/imports/france_top_ten.json) —
  GTFS and GTFS-RT for the ten largest French cities, compiled from
  [transport.data.gouv.fr](https://transport.data.gouv.fr/api/datasets), the
  Point d'Accès National.

Sources arrive **disabled**, so importing does not kick off ten static imports at
once; toggle the ones you want. Three of the ten are schedule-only — Paris, Lyon
and Strasbourg publish realtime as SIRI or behind a personal API key rather than
as open GTFS-RT — and each source's notes say why.
