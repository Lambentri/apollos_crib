# GTFS-realtime protobuf definitions

These generate the `TransitRealtime.*` modules in `lib/`. They are vendored
rather than fetched at build time so a build does not depend on four upstream
URLs staying up, and so a change to what we parse shows up as a diff.

| File | Upstream | Generates |
|---|---|---|
| `gtfs-realtime.proto` | [google/transit](https://raw.githubusercontent.com/google/transit/master/gtfs-realtime/proto/gtfs-realtime.proto) | `lib/gtfs_realtime_pb.ex` |
| `gtfs-realtime-NYCT.proto` | [OneBusAway](https://raw.githubusercontent.com/OneBusAway/onebusaway-gtfs-realtime-api/master/src/main/proto/com/google/transit/realtime/gtfs-realtime-NYCT.proto) | `lib/gtfs_realtime_nyct_pb.ex` |
| `gtfs-realtime-MTARR.proto` | [OneBusAway](https://raw.githubusercontent.com/OneBusAway/onebusaway-gtfs-realtime-api/master/src/main/proto/com/google/transit/realtime/gtfs-realtime-MTARR.proto) | `lib/gtfs_realtime_mtarr_pb.ex` |
| `gtfs-realtime-service-status.proto` | [OneBusAway](https://raw.githubusercontent.com/OneBusAway/onebusaway-gtfs-realtime-api/master/src/main/proto/com/google/transit/realtime/gtfs-realtime-service-status.proto) | `lib/gtfs_realtime_service_status_pb.ex` |

All four `extend` declarations across the three MTA files land in one
`lib/gtfs_realtime_pb_extension.ex` — that is how protobuf-elixir works, one
extension module per generated set.

## Regenerating

There is no protoc in this repo and no need for one to be installed globally.
Fetch a release binary, and use the plugin that ships in `deps/protobuf` by
running it off the umbrella's own compiled beams:

```sh
cd /tmp && curl -sSLO https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protoc-29.3-linux-x86_64.zip
unzip -q protoc-29.3-linux-x86_64.zip -d protoc

cat > /tmp/protoc-gen-elixir <<'SH'
#!/usr/bin/env bash
exec elixir \
  -pa <umbrella>/_build/dev/lib/protobuf/ebin \
  -pa <umbrella>/_build/dev/lib/jason/ebin \
  -e 'Application.load(:protobuf); Protobuf.Protoc.CLI.main([])'
SH
chmod +x /tmp/protoc-gen-elixir
```

`Application.load(:protobuf)` is load-bearing: the generator stamps its own
version into every file and reads it from the application spec, so without it
generation dies with `MatchError: :undefined`.

Then, from `apps/room_gtfs`:

```sh
/tmp/protoc/bin/protoc \
  --elixir_out=/tmp/out \
  --plugin=protoc-gen-elixir=/tmp/protoc-gen-elixir \
  -I priv/proto \
  priv/proto/com/google/transit/realtime/gtfs-realtime.proto \
  priv/proto/com/google/transit/realtime/gtfs-realtime-NYCT.proto \
  priv/proto/com/google/transit/realtime/gtfs-realtime-MTARR.proto \
  priv/proto/com/google/transit/realtime/gtfs-realtime-service-status.proto
```

and copy the results over the five files in `lib/` named in the table above.
The `-I priv/proto` matters: the MTA files `import
"com/google/transit/realtime/gtfs-realtime.proto"`, so the directory layout
under `priv/proto` has to match that path.

## The one local edit

`gtfs-realtime-NYCT.proto` and `gtfs-realtime-service-status.proto` both claim
extension number **1001 on `FeedHeader`** — `nyct_feed_header` and
`mercury_feed_header`. protobuf-elixir keys its extension registry on
`{extendee, tag}`, so declaring both collapses them into one entry and whichever
is generated later wins. A subway trip feed's header would then decode into
Mercury's struct, and `get_extension/3` would hand it back under either name
without complaint. protoc warns about this; it is not an error.

Both `extend` blocks are therefore commented out in place, with the reasoning at
the edit. Nothing here reads the feed header beyond `timestamp`, which is a
plain spec field, so this costs nothing today. Restoring either means first
deciding which of the two owns `FeedHeader#1001`.

Everything else the MTA extends is on a distinct extendee — `TripDescriptor`,
`StopTimeUpdate`, `Alert`, `EntitySelector`, `VehiclePosition.CarriageDetails` —
and is unaffected.

## Not vendored

MTA Bus vehicle positions carry an extension at **`VehiclePosition#1006`** that
none of these files define, and which is not OneBusAway's either (theirs is
1000). On the wire it is two varints, the first 1–53 and the second always 65,
80 or 100, the first never exceeding the second — passenger count and vehicle
capacity, almost certainly automatic passenger counting. Deliberately left
unparsed until there is a definition to name the fields from; it shows up in
`__unknown_fields__` and is ignored.
