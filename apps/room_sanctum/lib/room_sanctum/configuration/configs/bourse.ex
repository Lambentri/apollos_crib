defmodule RoomSanctum.Configuration.Configs.Bourse do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @moduledoc """
  Yahoo Finance quotes. Nothing to configure -- the endpoint is unauthenticated,
  so the offering exists to be enabled and to hold the queries beneath it.
  """

  embedded_schema do
  end

  def changeset(source, params) do
    source
    |> cast(params, [])
    |> validate_required([])
  end
end
