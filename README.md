
# ApollosCrib

A generalized automated data collection platform, for the purpose of collecting and displaying timely data for wherever you may be.

It supports the creation of offerings data from 8 generalized sources at this time:

- GTFS (+RT)
- GBFS
- iCal
- Tidal
- Ephem
- AirNow
- OpenWeather
- Cronos

These can be formed into reusable Queries that can be grouped into Visions.
Visions are interpreted by the Pythiae who forward them to clients via Ankyra.

## Public Demo

The public demo instance https://ac.gmp.io/ is here, and the landing data displays queries for various entities around Assembly Row, Somerville, MA, US


### Development

Debian/Ubuntu users may need to isntall `erlang-xmerl`

#### Migrations

Migrations need to be run from within the `room_sanctum`/`room_hermes` directories in that order.
