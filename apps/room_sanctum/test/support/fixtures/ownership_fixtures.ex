defmodule RoomSanctum.OwnershipFixtures do
  @moduledoc """
  Records belonging to a given user, for the tests that check one user's
  record cannot point at another's.
  """

  alias RoomSanctum.{Accounts, Configuration, Repo}

  def owner do
    {:ok, user} =
      Accounts.register_user(%{
        email: "owner#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    user
  end

  def source_for(user, attrs \\ %{}) do
    {:ok, source} =
      %{
        name: "Markets",
        notes: "",
        type: :bourse,
        enabled: true,
        user_id: user.id,
        config: %{"__type__" => "bourse"}
      }
      |> Map.merge(attrs)
      |> Configuration.create_source()

    source
  end

  def query_for(user) do
    {:ok, query} =
      Configuration.create_query(%{
        name: "AAPL",
        notes: "",
        source_id: source_for(user).id,
        user_id: user.id,
        query: %{"__type__" => "bourse", "symbol" => "AAPL"}
      })

    query
  end

  def foci_for(user) do
    {:ok, foci} =
      Configuration.create_foci(%{
        name: "Home",
        user_id: user.id,
        place: %Geo.Point{coordinates: {-71.0589, 42.3601}, srid: 4326}
      })

    foci
  end

  def vision_for(user) do
    {:ok, vision} = Configuration.create_vision(%{name: "Dash", user_id: user.id})
    vision
  end

  def plani_for(user) do
    {:ok, plani} =
      Configuration.create_plani(%{
        name: "Pocket",
        user_id: user.id,
        home_foci_id: foci_for(user).id
      })

    plani
  end

  def ankyra_for(user) do
    {:ok, ankyra} =
      Accounts.create_rabbit_user(%{
        username: Ecto.UUID.generate(),
        password: "hunter2",
        topic: "Some-Topic",
        user_id: user.id
      })

    ankyra
  end

  @doc """
  users_rabbit comes from the hermes repo's migrations and is not in the
  sanctum test database. Made inside the test's sandbox transaction, so it goes
  when the test does.
  """
  def users_rabbit!(_ctx \\ %{}) do
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS users_rabbit (
      id bigserial PRIMARY KEY,
      password varchar,
      username uuid,
      topic varchar,
      client_ids varchar[] DEFAULT '{}',
      auto_register_clients boolean DEFAULT true,
      user_id bigint,
      inserted_at timestamp,
      updated_at timestamp
    )
    """)

    :ok
  end
end
