#!/bin/sh
#
# Run pending migrations, then start the server.
#
# Both repos live in one database and share one schema_migrations table, so
# this is the same work `mix ecto.migrate` does at the umbrella root -- each
# migrator only runs the files its own app ships.
#
# set -e matters: if a migration fails the container exits non-zero and never
# serves, so Kubernetes keeps the previous pod up rather than rolling out one
# running new code against an old schema. Ecto takes an advisory lock per repo,
# so the overlap during a rolling update is safe.
set -e

echo "==> apollos-crib: migrating"
/opt/app/bin/start_server eval 'RoomSanctum.Release.migrate(); RoomHermes.Release.migrate()'

echo "==> apollos-crib: starting"
exec /opt/app/bin/start_server start
