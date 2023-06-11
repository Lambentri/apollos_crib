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

  @doc """
  Generate a vision.
  """
  def vision_fixture(attrs \\ %{}) do
    {:ok, vision} =
      attrs
      |> Enum.into(%{
        name: "some name",
        queries: %{}
      })
      |> RoomSanctum.Configuration.create_vision()

    vision
  end

  @doc """
  Generate a foci.
  """
  def foci_fixture(attrs \\ %{}) do
    {:ok, foci} =
      attrs
      |> Enum.into(%{
        name: "some name",
        place: "some place"
      })
      |> RoomSanctum.Configuration.create_foci()

    foci
  end

  @doc """
  Generate a pythiae.
  """
  def pythiae_fixture(attrs \\ %{}) do
    {:ok, pythiae} =
      attrs
      |> Enum.into(%{
        ankyra: [],
        visions: []
      })
      |> RoomSanctum.Configuration.create_pythiae()

    pythiae
  end

  @doc """
  Generate a scribus.
  """
  def scribus_fixture(attrs \\ %{}) do
    {:ok, scribus} =
      attrs
      |> Enum.into(%{
        configuration: [],
        name: "some name",
        resolution: "some resolution"
      })
      |> RoomSanctum.Configuration.create_scribus()

    scribus
  end
end
