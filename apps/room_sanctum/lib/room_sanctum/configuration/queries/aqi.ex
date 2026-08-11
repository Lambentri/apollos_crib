defmodule RoomSanctum.Configuration.Queries.AQI do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  Air quality for one place.

  Either a foci -- take whichever monitoring station is nearest to it, which is
  what you want for "the air where I live" and keeps working when a station
  goes offline -- or a specific station by its AQS id, for watching one
  monitor. A station id wins if both are set.
  """

  embedded_schema do
    field :foci_id, :integer
    field :aqsid, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, [:foci_id, :aqsid])
    |> blank_to_nil(:aqsid)
    |> validate_a_place()
  end

  # The form submits "" for an untouched field, which would otherwise read as
  # "a station was chosen" and match nothing.
  defp blank_to_nil(changeset, field) do
    case get_change(changeset, field) do
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> put_change(changeset, field, nil)
          trimmed -> put_change(changeset, field, trimmed)
        end

      _ ->
        changeset
    end
  end

  defp validate_a_place(changeset) do
    case {get_field(changeset, :foci_id), get_field(changeset, :aqsid)} do
      {nil, nil} ->
        add_error(changeset, :foci_id, "pick a foci, or name a station")

      _ ->
        changeset
    end
  end
end
