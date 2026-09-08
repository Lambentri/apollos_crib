defmodule RoomSanctum.FranceImportBundleTest do
  @moduledoc """
  The shipped France bundle has to survive the Import Offerings page.

  It is a hand-written file rather than something exported from a running
  instance, so nothing else would notice a typo in a field name -- the page
  would simply show ten red cards to whoever pasted it.
  """

  use ExUnit.Case, async: true

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Source

  @bundle Application.app_dir(:room_sanctum, "priv/imports/france_top_ten.json")

  defp sources do
    @bundle |> File.read!() |> Poison.decode!() |> Map.fetch!("sources")
  end

  # What the import page does to a pasted source before validating it.
  defp changeset(source) do
    attrs =
      source
      |> Map.drop(["id", "inserted_at", "updated_at"])
      |> Map.put("user_id", 1)
      |> atomize_keys()

    Configuration.change_source(%Source{}, attrs)
  end

  defp atomize_keys(map) when is_map(map) do
    map
    |> Map.new(fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, atomize_keys(v)}
    end)
  rescue
    ArgumentError -> map
  end

  defp atomize_keys(value), do: value

  test "the bundle is the ten cities, each a gtfs source" do
    names = Enum.map(sources(), & &1["name"])

    assert length(names) == 10

    for city <- ~w(Paris Marseille Lyon Toulouse Nice Nantes Montpellier
                   Strasbourg Bordeaux Lille) do
      assert Enum.any?(names, &String.starts_with?(&1, city)),
             "no source for #{city}, only: #{inspect(names)}"
    end

    assert Enum.all?(sources(), &(&1["type"] == "gtfs"))
  end

  test "every source validates the way the import page validates it" do
    for source <- sources() do
      cs = changeset(source)
      assert cs.valid?, "#{source["name"]}: #{inspect(cs.errors)}"
    end
  end

  test "every feed is https, and on Paris time" do
    for source <- sources(), {field, url} <- source["config"], field != "__type__" do
      case field do
        "tz" -> assert url == "Europe/Paris", "#{source["name"]} is not on Paris time"
        "url" <> _ -> assert String.starts_with?(url, "https://"), "#{source["name"]}: #{url}"
        _ -> :ok
      end
    end
  end

  test "sources arrive disabled, so ten static imports do not start at once" do
    assert Enum.all?(sources(), &(&1["enabled"] == false))
  end

  test "the feeds behind the PAN proxy poll slower than its rate limit" do
    # One request per 30 seconds per resource; above that it answers 429.
    for source <- sources(), {field, url} <- source["config"], is_binary(url) do
      if String.starts_with?(url, "https://proxy.transport.data.gouv.fr/") do
        kind = String.replace_prefix(field, "url_rt_", "")
        period = source["config"]["rt_period_#{kind}"]

        assert is_integer(period) and period >= 30,
               "#{source["name"]} polls #{field} every #{inspect(period)}s"
      end
    end
  end
end
