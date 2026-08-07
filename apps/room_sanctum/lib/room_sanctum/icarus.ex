defmodule RoomSanctum.Icarus do
  @moduledoc """
  Context for flight watches -- the durable half of `RoomIcarus.Worker`.

  The worker keeps volatile positions in memory, but a watch's identity (which
  airframe we latched, whether it has landed) is written through to Postgres so
  a restart mid-flight resumes rather than re-latching.
  """

  import Ecto.Query, warn: false

  alias RoomSanctum.Repo
  alias RoomSanctum.Storage.Icarus.FlightWatch

  def get_watch(callsign, dest, sched_arrival) do
    Repo.get_by(FlightWatch, callsign: callsign, dest: dest, sched_arrival: sched_arrival)
  end

  @doc """
  Fetch the watch for a flight instance, creating it on first look.

  Racy by nature -- two LiveViews can ask at once -- so an insert that loses the
  unique-index race falls back to reading the winner's row.
  """
  def ensure_watch(callsign, dest, sched_arrival) do
    case get_watch(callsign, dest, sched_arrival) do
      %FlightWatch{} = watch ->
        {:ok, watch}

      nil ->
        %FlightWatch{}
        |> FlightWatch.changeset(%{
          callsign: callsign,
          dest: dest,
          sched_arrival: sched_arrival,
          state: "pending"
        })
        |> Repo.insert()
        |> case do
          {:ok, watch} ->
            {:ok, watch}

          {:error, _} ->
            case get_watch(callsign, dest, sched_arrival) do
              nil -> {:error, :unavailable}
              watch -> {:ok, watch}
            end
        end
    end
  end

  def update_watch(%FlightWatch{} = watch, attrs) do
    watch
    |> FlightWatch.changeset(attrs)
    |> Repo.update()
  end

  @doc "Watches still worth polling, for the worker's periodic sweep."
  def active_watches do
    from(w in FlightWatch, where: w.state in ["pending", "enroute"])
    |> Repo.all()
  end

  @doc """
  Drop watches whose flight is long over, so the table does not grow without
  bound. Anything more than a week past its scheduled arrival is dead weight.
  """
  def prune_watches(now \\ DateTime.utc_now()) do
    cutoff = DateTime.add(now, -7 * 24 * 3600)

    from(w in FlightWatch, where: w.sched_arrival < ^cutoff)
    |> Repo.delete_all()
  end
end
