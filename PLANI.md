# Plani

A foci that moves.

A [Foci](README.md) anchors a query in one place. A Plani anchors it wherever
the client reporting to it currently is, and falls back to a home foci when
nothing has reported for a while. The point is a vision that answers "what is
near me" rather than "what is near Davis Square".

This is a scope, not a description of something that exists. What is built so
far is the plumbing underneath it, noted below.

## Where the position lives

**In a GenServer, and nowhere else.** A Plani's row in the database holds its
configuration — a name, a home foci, the sources attached to it — and never a
coordinate. The current position exists in the worker's memory, expires on a
timer, and goes when the process does.

That is a deliberate constraint rather than an implementation detail. A table
of where somebody has been is a different kind of thing from a board of when
the next bus is, with different obligations attached to it, and this avoids
having one. It also makes the fallback obvious: when there is no position in
memory there is nothing to fall back *from*, so the home foci answers.

```
                    fresh fix?  ──yes──▶  the client's position
  Plani.anchor()  ──┤
                    └──no───▶  home foci's place  (from the database)
```

## What already exists

More than it looks, because the pieces were built for other reasons.

| Piece | Where | State |
| --- | --- | --- |
| A client may publish to its Ankyra | `RoomHermesWeb.TopicController`, `<topic>.up.` | done |
| A client reports its position, opt-in | `clients/android`, `LocationReporter` | done |
| Positions arrive and are held for five minutes | `RoomSanctum.Worker.Ankyra` | done |
| The trail is visible | `cfg/ankyra/:id` | done |
| A client can ask for a fresh board | `<topic>.publish.`, `Pythiae.query_current_now/1` | done |

And one piece of shape that matters more than any of it: **the storage layer
already separates resolving an anchor from searching near a point.**

```elixir
def nearest_aqi_stations(source_id, foci_id, limit)   # resolves a foci, then:
def nearby_aqi_stations(source_id, %Geo.Point{}, limit)
```

A Plani is largely a matter of handing a different point to functions that
already take one.

## The part that is not uniform

"Most of our datapoints have a latlon attached someplace" is true, but they do
not have it in the same place, and — more importantly — **"the closest N" only
means something for some of them.** Attaching a source to a Plani means one of
three different things:

**Sources that store many located things.** Nearest-N is the natural question,
and the work is a spatial query.

| Source | Where the location is | Ready? |
| --- | --- | --- |
| `gbfs` stations | `gbfs_station_information.place`, PostGIS | yes — `ST_DWithin` + `<->` ordering already used |
| `gbfs` free bikes | `gbfs_free_bike_status`, PostGIS | yes |
| `aqi` monitors | `airnow_hourly_observations.point`, PostGIS | yes — `nearby_aqi_stations/3` |
| `gtfs` stops | `gtfs_stops.place`, generated from `stop_lat` / `stop_lon` | yes — `nearby_stops/3`, GiST indexed |

GTFS was the gap and is now closed. The column is generated rather than
written, because the importer builds its bulk inserts from the schema's fields
and would otherwise have to maintain it; a generated column cannot drift from
the coordinates it comes from and stays out of the importer's way by staying
out of the Ecto schema.

**Sources answered *at* a point rather than *near* one.** Weather, sunrise,
pollen, what is overhead: there is one answer and it is computed for wherever
you are. Done, via `Configuration.place_for!/1` — every one of them resolved a
foci with the same two lines, so they now take a place when one is handed over
and a foci id otherwise. `weather`, `ephem`, `pollen` and `icarus` relocate;
`cronos` uses its foci for a timezone rather than a position, and `calendar`
for filtering, so neither moves.

**Sources with no location.** `github`, `gitlab`, `packages`, `mailbox`,
`treasury`, `bourse`. A Plani should either refuse these or pass them through
untouched; "the nearest CI job" is not a thing. Worth deciding explicitly
rather than discovering at runtime.

## Suggested order

1. **The anchor.** A Plani row (name, home foci, sources) and a worker that
   resolves a position: freshest fix from the Ankyra worker's trail, else the
   home foci. Publishes nothing yet — but the resolution, the expiry and the
   fallback are the part with the design risk in it, and it can be watched on
   a page before anything depends on it.
2. ~~**Relocatable point sources.**~~ Done: `place_for!/1` is the one helper
   they all use, so a Plani relocates weather, sunrise, pollen and aircraft
   without any of them knowing what a Plani is.
3. **Nearest-N for what is already indexed.** GBFS stations and bikes, AQI
   monitors. The queries exist; they need a limit and a caller.
4. ~~**GTFS stops.**~~ Done: `gtfs_stops.place` is generated and GiST indexed,
   `nearby_stops/3` uses it, and GTFS queries have a `mode: :area` that asks
   what is leaving near a foci. Both spatial sources now move when their
   anchor does.

## Open questions

- **N or a radius?** "Five nearest" and "everything within 500m" answer
  differently when you are somewhere empty. GBFS queries already take a
  radius; nearest-N would be a second mode rather than a replacement.
- **Is a Plani its own thing, or a mode on a Pythiae?** Settled: not a mode,
  and nothing XORs with visions. A Pythiae already carries `curr_foci`, which
  is settable in the UI and read by nothing. If a query resolved its anchor
  through the Pythiae's `curr_foci` rather than its own `foci_id`, the same
  vision would answer for wherever the Pythiae is pointed, and a Plani would
  be a foci whose place comes from a GenServer rather than a column. The
  vision machinery, the condensers and the clients would all be untouched.

  What did *not* compose was asking for things there was no query for. Both
  GBFS and GTFS now have `mode: :area` around a foci, so "what is near me"
  works the moment the foci moves. That was a query mode rather than a
  Pythiae mode, which is the shape the rest of this should keep.

  What remains is the substitution itself: nothing yet reads `curr_foci`, so
  a query still resolves its own `foci_id`. That is the one piece of wiring
  between here and a foci that travels.
- **What does a client see while it has never reported?** The home foci, which
  is correct but silent. A board that says which anchor it used would save
  somebody wondering why the times are for the wrong town.
- **Which Ankyra?** A Plani follows *a* client. An Ankyra with two clients
  reporting has two positions and no rule for choosing between them.
