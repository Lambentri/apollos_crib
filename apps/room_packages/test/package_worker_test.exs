defmodule RoomPackages.WorkerTest do
  @moduledoc """
  The USPS poll, against a stand-in for the tracking endpoint.

  More pending numbers than one request can carry go out in batches, and each
  batch has to build on what the one before it wrote:
  `update_source_meta_tracking/3` rewrites the whole tracking list from the
  struct it is handed.
  """
  use ExUnit.Case, async: false

  alias RoomSanctum.{Accounts, Configuration, Repo}

  defmodule FakeUSPS do
    @moduledoc false
    # Answers every number it is asked about as in transit.
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      {:ok, body, conn} = read_body(conn)

      answers =
        body
        |> Jason.decode!()
        |> Enum.map(&%{"trackingNumber" => &1["trackingNumber"], "status" => "In Transit"})

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(answers))
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    start_supervised!({Plug.Cowboy, scheme: :http, plug: FakeUSPS, options: [port: 0]})
    port = :ranch.get_port(FakeUSPS.HTTP)

    previous = Application.get_env(:room_packages, :usps_tracking_base)
    Application.put_env(:room_packages, :usps_tracking_base, "http://127.0.0.1:#{port}")

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:room_packages, :usps_tracking_base)
        base -> Application.put_env(:room_packages, :usps_tracking_base, base)
      end
    end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "parcels#{System.unique_integer([:positive])}@example.com",
        password: "hello world!hello world!"
      })

    %{user: user}
  end

  defp source_tracking(user, count) do
    expiry = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_iso8601()

    {:ok, source} =
      Configuration.create_source(%{
        name: "Parcels",
        notes: "",
        type: :packages,
        enabled: true,
        user_id: user.id,
        config: %{
          "__type__" => "packages",
          "apikey_usps_id" => "id",
          "apikey_usps_secret" => "secret",
          # A token that has not expired, so no mint is attempted.
          "token_usps" => "token",
          "token_usps_expiry" => expiry
        },
        meta: %{
          tracking:
            for n <- 1..count do
              %{number: "9400#{n}", type: :usps, entries: []}
            end
        }
      })

    source
  end

  test "every batch's updates survive when the numbers need more than one request", %{
    user: user
  } do
    count = RoomPackages.USPS.max_batch() + 1
    source = source_tracking(user, count)

    {:noreply, state} = RoomPackages.Worker.handle_cast(:refresh, %{id: source.id, data: []})

    tracking = Configuration.get_source!(source.id).meta.tracking
    assert length(tracking) == count

    without = for t <- tracking, t.entries in [nil, []], do: t.number
    assert without == []

    assert Enum.all?(state.data, &(length(&1.entries) == 1))
  end
end
