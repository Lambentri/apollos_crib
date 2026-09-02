# Apollo's Crib for Android

A [Smartspacer](https://github.com/KieronQuinn/Smartspacer) plugin that puts a
vision's queries on the Android home and lock screen.

It is an Ankyra client, the same as `clients/lilygo4.7`: it subscribes to a
rabbit user's MQTT topic, keeps the last board it heard on disk, and draws it
as Smartspacer Targets. Nothing is polled and no HTTP endpoint is involved --
the Pythiae publishes on change and the phone redraws when it does.

## What it shows

One Target per source type, added once per query you care about:

| Target | Source | What it draws |
| --- | --- | --- |
| Transit | `gtfs` | Next departures from a stop, soonest route first, each time marked as realtime or scheduled; a severe or stop-specific alert gets its own card |
| Bikeshare | `gbfs` | Bikes, e-bikes and docks at a station, or loose bikes for an area query |
| Weather | `weather` | Current conditions at a focus |
| Tides | `tidal` | High and low water, in the order the day happens rather than the order the feed sends |
| Air quality | `aqi` | Whatever the monitor measured — nothing is assumed present |
| Sun and moon | `ephem` | Sunrise, sunset, moonrise, moonset, and the phase |
| Calendar | `calendar` | What is coming up, soonest first |
| Pollen | `pollen` | Grass, trees and weeds, worst first, in-season only |
| Drought | `drought` | Drought Monitor coverage, worst category with any of the area in it |
| GitLab / GitHub | `gitlab`, `github` | Recent CI jobs and runs, pass or fail as the row's glyph |
| Cronos, Packages, Constant | `cronos`, `packages`, `const` | Whatever the publisher sent: these are passthroughs, with no shape to render against |

Add the Transit target twice and you get two stops, each choosing its own query
when Smartspacer opens the setup screen.

### What is not here

[`apollos-types`](https://github.com/neiam/apollos-types) is the source of truth
for the wire format, and this client covers exactly the types it gives a shape
to. apollos-crib also publishes `icarus`, `mailbox`, `treasury`, `bourse`,
`hass` and `rideshare`, which the crate does not describe — so this cannot claim
to read them. They are named at the foot of the board rather than dropped in
silence. Adding one means adding it to the crate first.

## Setting it up

1. In Apollo's Crib, open the Ankyra at `cfg/ankyra/<id>` and scan the **Pair a
   Client** QR with the phone's camera. It carries the credentials, the topic
   and the broker address as an `apolloscrib://ankyra` link, which this app
   handles -- nothing is retyped and there is no scanner in here to break.
   Check the broker host on that page first: it is where the phone reaches
   RabbitMQ, which is not necessarily where the app is.

   Failing that, copy the username, password and topic across by hand.

   Either way, leave auto-registration on, or add the client id the app shows
   you to that Ankyra's client ids -- the broker will refuse the connection
   otherwise, and Ankyra counts its consumers by that id.
2. Point a Pythiae at the vision you want and give it that Ankyra.
3. Install this app, fill in the broker host, port (1883 for the RabbitMQ MQTT
   plugin) and those credentials, and connect. The screen shows the queries as
   they arrive.
4. In Smartspacer: Targets, add, Apollo's Crib. Pick the query the target shows.

Once there is a working connection the app opens on the board rather than the
form: every query in the vision, drawn from the same description its Smartspace
card is built from, updating as payloads land. What is on that screen is what a
Target added for that query will say. The connection is behind *Connection* in
the corner, and reconnects by itself on launch once it has worked once.

The connection is a foreground service with an ongoing notification. That is
what an always-open socket costs on Android; the alternative is polling, which
this deliberately does not do.

## As a launcher's feed page

Launchers that implement Google's "minus one" gesture -- the page to the left
of the home screen -- bind a service exposing `ILauncherOverlay` and hand it
their own window token. `feed/FeedOverlayService` is that service, so the board
is available as the feed page with nothing else installed.

The page is read-only by construction: it draws the same board the app does and
offers no way into the settings. A page you can swipe onto by accident should
not be able to change anything.

**Launchers check the provider's signature.** Lawnchair keeps a list in
`FeedBridge.initializeWhitelist`, keyed by package name and by
`Signature.hashCode()` -- an unlisted package is filtered out of the picker
before you ever see it. The Connection screen reports this build's hash for
that reason; it differs per keystore, so a debug build's is not a release
build's.

There is no way past it from a stock build. `CustomBridgeInfo.isSigned()` is
`ignoreWhitelist || (signatureHash != -1 && super.isSigned())`, and an unlisted
package has `signatureHash == -1` -- so the `BuildConfig.DEBUG` shortcut inside
`super.isSigned()` never applies to one, and a debug build of the launcher is
no help by itself. `pref_ignoreFeedWhitelist` is the only lever, and it lives
in a debug menu whose own enable switch lives inside that debug menu.

So testing means a launcher built with this package listed. One line, next to
the entry Neo Feed already has:

```kotlin
whitelist["io.neiam.apolloscrib"] = getSignatureHash(context, "io.neiam.apolloscrib")
```

`getSignatureHash` reads the hash off whatever is installed, so it matches a
debug build and a release one without either being written down.

Failing a launcher, `feed/OverlayHarnessActivity` in the debug build does what
a launcher does -- binds the service, hands over its own window token, drives
the scroll. It is how the window attach was got working, and it does not need
anybody's whitelist.

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

The board's glyphs are the ones the web board draws -- a bus for a bus, a
subway for a subway, a broadcast tower on a time the feed gave and a clock on
one the timetable did, a pin on an alert that names your stop. They are not
lookalikes: `tools/fa_to_vector.py` reads the Font Awesome metadata already
vendored at `clients/lilygo4.7/fontawesome-free-6.2.0-desktop` -- the same
source `RoomSanctumWeb.IconHelpers` and `live_preview.ex` name -- and emits the
same paths as Android drawables. Regenerate with:

```sh
python3 tools/fa_to_vector.py
```

Font Awesome Free icons are CC BY 4.0; the vendored `LICENSE.txt` covers them.

A Smartspace list row is plain text, so the glyphs are the app's alone. Rows
carry a text form for that surface -- `8b 1e 7d` rather than `8 1 7`, which is
not a number of bikes, e-bikes and docks to anybody reading it.
