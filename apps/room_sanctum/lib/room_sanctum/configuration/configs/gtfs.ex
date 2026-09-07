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

    # Whether realtime trip ids are the tail of the schedule's rather than the
    # whole thing. NYCT does this: realtime says "098600_5..S03R" where
    # gtfs_subway.zip says "ASP26GEN-1038-Sunday-00_098600_5..S03R", the leading
    # part being which published schedule the trip belongs to.
    #
    # Off by default, and deliberately not inferred. A suffix comparison is
    # looser than an exact one and can match a trip it should not; a feed that
    # needs it should say so rather than have it guessed from a bad day's data.
    field :rt_trip_id_suffix, :boolean, default: false

    # Headers to send with every request for this feed: static zip, realtime,
    # and the linked datasets a discovery file points at.
    #
    # Arbitrary because the schemes are. Some agencies want `apikey`, some
    # `x-api-key`, 511 wants it in the query string and needs none of this,
    # and TMB wants `Authorization: Bearer ...`. Naming a scheme here would
    # mean a new field for every operator with an opinion.
    field :headers, :map, default: %{}

    # What the form edits: one `Name: value` per line. The stored shape is the
    # map; this is the shape a person can type and read back.
    field :headers_raw, :string, virtual: true
  end

  def changeset(source, params) do
    source
    |> cast(
      params,
      ~w(url url_rt_sa url_rt_tu url_rt_vp url_rt_shared tz rt_agency
         rt_trip_id_suffix rt_period_tu rt_period_vp rt_period_sa headers)a
    )
    # Its own cast, with "" kept as a value rather than treated as nothing.
    # Ecto's default empty_values turns an emptied textarea into no change at
    # all, so clearing the box left the old headers in place -- which means an
    # API key could be added through this form and never taken away again.
    |> cast(params, [:headers_raw], empty_values: [])
    |> validate_required([:url, :tz])
    |> validate_periods()
    |> put_headers()
  end

  @doc """
  The configured headers in the shape HTTPoison wants.

  `[]` for a source that sets none, which is nearly all of them -- and which
  is also what every caller passed before this existed, so an unconfigured
  feed makes exactly the request it always did.
  """
  def request_headers(%{headers: headers}) when is_map(headers) do
    Enum.map(headers, fn {name, value} -> {to_string(name), to_string(value)} end)
  end

  def request_headers(_config), do: []

  @doc """
  The stored headers as the text the form edits: one `Name: value` per line.

  Sorted, so editing a source does not reshuffle the box every time it is
  opened -- a map has no order and a textarea that reorders itself looks like
  it changed something.
  """
  def headers_text(%{headers: headers}) when is_map(headers) and map_size(headers) > 0 do
    headers
    |> Enum.sort_by(fn {name, _value} -> name end)
    |> Enum.map_join("\n", fn {name, value} -> "#{name}: #{value}" end)
  end

  def headers_text(_config), do: ""

  @doc """
  Parse the textarea into a map, or say which line is wrong.

  Returns `{:ok, map}` or `{:error, line}`. Public because the form and the
  changeset both want it and a second copy of "what a header line looks like"
  is the kind of thing that drifts.
  """
  def parse_headers(text) when is_binary(text) do
    text
    |> String.split(~r/\r?\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce_while({:ok, %{}}, fn line, {:ok, acc} ->
      case String.split(line, ":", parts: 2) do
        [name, value] ->
          name = String.trim(name)
          value = String.trim(value)

          # A name with a space in it is not a header name, and is nearly
          # always a colon typed in the value of the line above.
          if name != "" and not String.contains?(name, " ") do
            {:cont, {:ok, Map.put(acc, name, value)}}
          else
            {:halt, {:error, line}}
          end

        _ ->
          {:halt, {:error, line}}
      end
    end)
  end

  def parse_headers(_text), do: {:ok, %{}}

  # Only when the form sent the text field. A changeset that does not mention
  # headers_raw -- anything not coming from that form -- leaves the stored
  # headers exactly as they were.
  defp put_headers(changeset) do
    case fetch_change(changeset, :headers_raw) do
      :error ->
        changeset

      {:ok, text} ->
        case parse_headers(text) do
          {:ok, headers} ->
            put_change(changeset, :headers, headers)

          {:error, line} ->
            add_error(changeset, :headers_raw, "expected \"Name: value\", got: #{line}")
        end
    end
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
