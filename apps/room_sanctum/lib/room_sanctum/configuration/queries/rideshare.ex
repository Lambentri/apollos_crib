defmodule RoomSanctum.Configuration.Queries.Rideshare do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    # tbd
  end

  def changeset(source, params) do
    source
    #    |> cast(params, ~w(api_key, provider)a)
    #    |> validate_required([:api_key, :provider])
  end
end
