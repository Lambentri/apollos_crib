defmodule RoomGtfs.Application do
  @moduledoc """
  Exists to register the protobuf extensions, and for nothing else.

  GTFS-realtime is extensible by design: agencies bolt their own fields onto
  the standard messages at tag numbers 1000-1999, and the MTA does this heavily
  -- NYCT subway train ids and track assignments, LIRR and Metro-North track
  and train status, Mercury service alerts. Those definitions live in
  `priv/proto` and generate into modules alongside the base spec.

  Defining them is not enough. `Protobuf.load_extensions/0` is what puts each
  {extendee, tag} into `:persistent_term` where the decoder looks, and until it
  runs the decoder has no idea tag 1001 means anything: the bytes decode, land
  in `__unknown_fields__` as an unparsed blob, and every extension accessor
  returns nil. That failure is completely silent, which is why this runs at
  boot rather than lazily at the first decode.

  It also owns `RoomGtfs.FeedCache`, so that several sources pointing at one
  realtime URL fetch it once between them, and `RoomGtfs.RTIndex`, the table
  the realtime feeds are read out of -- owned here rather than by a worker so
  that a worker restarting does not take its source's data with it. The per-source workers are not
  started here -- room_zeus does that, one per configured source.
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Scans every loaded application for `*.PbExtension` modules, so it has to
    # run after this app's own modules are loadable -- which, being this app's
    # start callback, it is.
    :ok = Protobuf.load_extensions()

    children = [static_pool(), RoomGtfs.FeedCache, RoomGtfs.RTIndex]

    Supervisor.start_link(children, strategy: :one_for_one, name: RoomGtfs.Supervisor)
  end

  # The connection pool the static feed downloads use.
  #
  # Started here with a size rather than left for hackney to create on demand,
  # because the size is the point. A static feed is the whole timetable and
  # they run to a hundred megabytes; four at once is already several hundred
  # megabytes in flight, and each one holds its connection for minutes. Left
  # unbounded, a scheduled refresh of every source at once would try to hold
  # them all.
  #
  # Separate from hackney's default pool for the same reason. Everything else
  # in this umbrella -- realtime feeds, GitHub, the weather -- shares that one,
  # and a bulk transfer sitting in it starves requests that take milliseconds.
  defp static_pool do
    :hackney_pool.child_spec(:gtfs_static, max_connections: 4, timeout: 300_000)
  end
end