defmodule RoomSanctum.Configuration.Configs.GTFS do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :url, :string
    field :url_rt_sa, :string
    field :url_rt_tu, :string
    field :url_rt_vp, :string
    field :tz, :string
  end

  def changeset(source, params) do
    source
    |> cast(params, ~w(url url_rt_sa url_rt_tu url_rt_vp tz)a)
    |> validate_required([:url, :tz])
  end
end
