# Apollo's Crib for Android

A [Smartspacer](https://github.com/KieronQuinn/Smartspacer) plugin that puts a
vision's queries on the Android home and lock screen.

It is an Ankyra client, the same as `clients/lilygo4.7`: it subscribes to a
rabbit user's MQTT topic, keeps the last board it heard on disk, and draws it
as Smartspacer Targets. Nothing is polled and no HTTP endpoint is involved --
the Pythiae publishes on change and the phone redraws when it does.

## What it shows

| Target | Source | What it draws |
| --- | --- | --- |
| Transit | `gtfs` | The next departures from a stop, soonest route first, with a separate target for a severe or stop-specific alert |
| Bikeshare | `gbfs` | Bikes and docks at a station, or loose bikes for an area query |
| Weather | `weather` | Current conditions at a focus |

Each is added once per query: add the Transit target twice and you get two
stops, each choosing its own query when Smartspacer opens the setup screen.

## Setting it up

1. In Apollo's Crib, go to `cfg/ankyra` and note the rabbit user's **username**,
   **password** and **topic**. Leave auto-registration on, or add the client id
   the app shows you to that Ankyra's client ids -- the broker will refuse the
   connection otherwise, and Ankyra counts its consumers by that id.
2. Point a Pythiae at the vision you want and give it that Ankyra.
3. Install this app, fill in the broker host, port (1883 for the RabbitMQ MQTT
   plugin) and those credentials, and connect. The screen shows the queries as
   they arrive.
4. In Smartspacer: Targets, add, Apollo's Crib. Pick the query the target shows.

The connection is a foreground service with an ongoing notification. That is
what an always-open socket costs on Android; the alternative is polling, which
this deliberately does not do.

## Building

```sh
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

The debug APK is large (~36 MB) because HiveMQ's MQTT client brings Netty and
RxJava. Release builds have optimization switched off in `app/build.gradle.kts`
for now -- turning it on wants the SDK keep rule from the Smartspacer wiki.

## The wire format

The payload is one JSON object per tick, keyed `"<type>-<queryId>"`:

```json
{
  "gtfs-12": {
    "data": [
      {"route": "14", "route_name": "14", "dest": "Heath St", "dir": "Inbound",
       "mode": "Bus", "times": ["08:00:00"], "color": "#FFC72C"}
    ],
    "query": {"name": "Forest Hills", "meta": {}}
  }
}
```

A publisher that could not resolve the query sends the bare list instead of the
`{data, query}` wrapper; both are read.

**[`apollos-types`](https://github.com/neiam/apollos-types) is the source of
truth for these shapes.** The Kotlin types in `types/` mirror that crate --
when a field is added there, add it here. Unknown fields are ignored rather
than fatal, so a newer publisher does not break an older phone.

## Adding a source

The seam is deliberate. Weather is in here as the worked example of how small
it should be:

1. A type in `types/`, mirroring the crate's struct.
2. An entry in `SourceType`.
3. A `SourceRenderer` in `targets/`, which is the only place that decides what
   the thing looks like.
4. A four-line `ApollosTargetProvider` subclass, added to `Targets`.
5. A `<provider>` in the manifest with its own authority.

Everything else -- the subscription, the store, staleness, dismissal, binding a
target to a query -- is already handled and does not need touching.

## Look

The palette and typography are lifted from the DMS Android app: the same OKLCh
themes ("Her", "After Dark", "Forest" ...) that the Scribus public routes render
under, and B612 for text. The Smartspace targets themselves are drawn by the
launcher and are not ours to type.
