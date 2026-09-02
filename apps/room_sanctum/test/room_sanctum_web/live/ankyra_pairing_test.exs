defmodule RoomSanctumWeb.AnkyraPairingTest do
  @moduledoc """
  An Ankyra's connection, handed to a phone as a link rather than as five
  fields to retype.

  The page itself is not mounted here: `users_rabbit` is created by the hermes
  repo's migrations and is not in the sanctum test database, so there is no
  Ankyra to render. What is worth testing is the link, and that is a function.
  """
  use ExUnit.Case, async: true

  alias RoomSanctum.Accounts.RabbitUser
  alias RoomSanctumWeb.AnkyraLive.Show

  defp ankyra do
    %RabbitUser{
      username: "dff93bf2-12dd-4680-b4b0-77254b95fe48",
      password: "hunter2",
      topic: "Iodized-Nutritious-Xenoposeidon"
    }
  end

  defp broker(overrides \\ %{}) do
    Map.merge(%{host: "ac.neiam.org", port: 1883, tls: false}, overrides)
  end

  describe "the pairing link" do
    test "carries everything a client needs to subscribe" do
      uri = Show.pairing_uri(ankyra(), broker())
      %URI{scheme: scheme, host: host, query: query} = URI.parse(uri)
      params = URI.decode_query(query)

      assert scheme == "apolloscrib"
      assert host == "ankyra"
      assert params["host"] == "ac.neiam.org"
      assert params["port"] == "1883"
      assert params["user"] == "dff93bf2-12dd-4680-b4b0-77254b95fe48"
      assert params["pass"] == "hunter2"
      assert params["topic"] == "Iodized-Nutritious-Xenoposeidon"
      assert params["tls"] == "0"
    end

    test "says so when the broker wants TLS" do
      uri = Show.pairing_uri(ankyra(), broker(%{port: 8883, tls: true}))
      params = uri |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

      assert params["port"] == "8883"
      assert params["tls"] == "1"
    end

    test "a topic with characters a URL minds survives the round trip" do
      # Rabbit topics are generated names, but nothing stops one being edited
      # into something with a space or an ampersand in it.
      awkward = %{ankyra() | topic: "Front Door & Back"}
      uri = Show.pairing_uri(awkward, broker())
      params = uri |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

      assert params["topic"] == "Front Door & Back"
    end
  end
end
