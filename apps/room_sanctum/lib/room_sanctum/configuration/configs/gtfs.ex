defmodule RoomSanctum.Configuration.Configs.GTFS do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :url, :string
    field :url_rt_sa, :string
    field :url_rt_tu, :string
    field :url_rt_vp, :string

    # One feed carrying more than one kind of entity. Plenty of agencies publish
    # trip updates, vehicle positions and alerts in three files; some put them
    # in one message, and the MTA's subway feeds are the clearest case -- a
    # single URL that is 67 trip updates, 45 vehicle positions and an alert.
    #
    # Any kind without a URL of its own is taken from here, so a source with a
    # combined feed sets this alone, and one with a combined feed plus a
    # separate alerts feed sets this and url_rt_sa. Specific beats general.
    field :url_rt_shared, :string

    field :tz, :string

    # Seconds between realtime polls, per kind, because the three kinds do not
    # deserve the same cadence. Trip updates go stale in seconds; service alerts
    # change a few times a day and polling them as often as vehicle positions is
    # pure waste -- and waste is not free where a feed is metered. 511.org
    # allows 60 requests an hour on a default token.
    #
    # Nil is the default interval, not "never": see RoomGtfs.Worker.RT.
    field :rt_period_tu, :integer
    field :rt_period_vp, :integer
    field :rt_period_sa, :integer

    # Operator code for a feed that carries several agencies at once, e.g. "SF"
    # for a source reading 511's regional feed. Realtime entities there are
    # keyed `SF:trip_id`, so this both selects the ones belonging to this source
    # and says what prefix to strip. Left blank for a single-agency feed, which
    # is nearly all of them.
    field :rt_agency, :string
  end

  def changeset(source, params) do
    source
    |> cast(
      params,
      ~w(url url_rt_sa url_rt_tu url_rt_vp url_rt_shared tz rt_agency
         rt_period_tu rt_period_vp rt_period_sa)a
    )
    |> validate_required([:url, :tz])
    |> validate_periods()
  end

  # Below about ten seconds the poller cannot keep up and the feed will not have
  # changed anyway; the upper bound is a day, past which it is not realtime by
  # any reading.
  defp validate_periods(changeset) do
    Enum.reduce([:rt_period_tu, :rt_period_vp, :rt_period_sa], changeset, fn field, acc ->
      validate_number(acc, field, greater_than_or_equal_to: 10, less_than_or_equal_to: 86_400)
    end)
  end
end
