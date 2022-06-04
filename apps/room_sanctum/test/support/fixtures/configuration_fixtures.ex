defmodule RoomSanctum.ConfigurationFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RoomSanctum.Configuration` context.
  """

  @doc """
  Generate a source.
  """
  def source_fixture(attrs \\ %{}) do
    {:ok, source} =
      attrs
      |> Enum.into(%{
        config: %{},
        enabled: true,
        name: "some name",
        notes: "some notes",
        type: :aqi
      })
      |> RoomSanctum.Configuration.create_source()

    source
  end

  @doc """
  Generate a query.
  """
  def query_fixture(attrs \\ %{}) do
    {:ok, query} =
      attrs
      |> Enum.into(%{
        name: "some name",
        notes: "some notes",
        query: %{}
      })
      |> RoomSanctum.Configuration.create_query()

    query
  end
end
