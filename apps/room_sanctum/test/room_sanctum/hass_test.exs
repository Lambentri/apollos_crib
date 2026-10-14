defmodule RoomSanctum.HassTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.Hass

  defp board do
    %{
      "gtfs-2" => %{
        query: %{name: "Broadway @ Holland St", meta: %{}},
        data: [
          %{
            route: "88",
            route_name: "88",
            dest: "Lechmere",
            dir: "Inbound",
            mode: "Bus",
            times: ["16:55:00"],
            times_live: ["16:56:25"]
          }
        ]
      },
      "gbfs-4" => %{
        query: %{name: "Teele Square", meta: %{}},
        data: [
          %{name: "Teele Square", id: "f834", avail: 1, avail_elec: 0, docks_avail: 14},
          %{kind: :free_bike, name: "E-bike", id: "b1", lat: 0, lon: 0}
        ]
      },
      "aqi-34" => %{
        query: %{name: "CAMBERVILLE", meta: %{}},
        data: [%{pm25: 34, no2: 6, combined: "PM2.5: 34, NO2: 6, ", name: "Boston Metro"}]
      },
      "cronos-9" => %{query: %{name: "Timers", meta: %{}}, data: [%{id: 1}]}
    }
  end

  defp devices(board, reading \\ :basic),
    do: board |> then(&Hass.board_devices(7, "Velvety", &1, reading)) |> Map.new()

  test "a device per query, read from the Ankyra's own topic" do
    devices = devices(board())

    assert Map.keys(devices) |> Enum.sort() ==
             ~w(apollos_a7_aqi_34 apollos_a7_cronos_9 apollos_a7_gbfs_4 apollos_a7_gtfs_2)

    stop = devices["apollos_a7_gtfs_2"]
    assert stop.state_topic == "Velvety"
    assert stop.device.name == "Broadway @ Holland St"
    assert %{name: "88 to Lechmere", device_class: "timestamp"} = stop.components["88_lechmere_inbound"]
  end

  test "picks a route out of the payload by what it is, not where it sits" do
    template = devices(board())["apollos_a7_gtfs_2"].components["88_lechmere_inbound"].value_template

    assert template =~ ~s|value_json.get("gtfs-2")|
    assert template =~ ~s|selectattr('route', 'eq', "88")|
    assert template =~ ~s|selectattr('dest', 'eq', "Lechmere")|
  end

  test "Plus is read from its own topic, and keeps the devices Basic made" do
    plus =
      board()
      |> Map.delete("gtfs-2")
      |> Map.put("gtfs_plus-2", put_in(board()["gtfs-2"], [:data], [%{route: "88", dest: "Lechmere", dir: "Inbound", arrivals: []}]))

    stop = devices(plus, :plus)["apollos_a7_gtfs_2"]

    assert stop.state_topic == "Velvety/plus"
    assert stop.components["88_lechmere_inbound"].value_template =~ "d.arrivals"
  end

  test "a dock is three sensors, and a loose bike is none" do
    components = devices(board())["apollos_a7_gbfs_4"].components

    assert Map.keys(components) |> Enum.sort() == ~w(f834_avail f834_avail_elec f834_docks_avail)
    assert components["f834_avail"].name == "Teele Square bikes"
  end

  test "each pollutant measured, and not the summary string" do
    components = devices(board())["apollos_a7_aqi_34"].components

    assert Map.keys(components) |> Enum.sort() == ~w(boston_metro_no2 boston_metro_pm25)
    assert components["boston_metro_pm25"].device_class == "aqi"
  end

  test "a type with no obvious number is counted" do
    assert %{"items" => %{name: "Items"}} = devices(board())["apollos_a7_cronos_9"].components
  end

  test "unique ids are scoped to the Ankyra, so two can feed one Home Assistant" do
    ids =
      for {_, d} <- devices(board()), {_, c} <- d.components, do: c.unique_id

    assert Enum.all?(ids, &String.starts_with?(&1, "apollos_a7_"))
    assert ids == Enum.uniq(ids)
  end

  test "a Keryx query is read from its .meta, and expires when it stops" do
    {object_id, device} = Hass.keryx_device(5, 12, :gtfs, board()["gtfs-2"])

    assert object_id == "apollos_k5_12"
    assert device.state_topic == "apollos/keryx/5/gtfs/12/meta"
    assert device.expire_after == 300
    assert device.components["88_lechmere_inbound"].value_template =~ "{% set e = value_json %}"
  end

  test "discovery sits under the Ankyra's topic, where its rabbit user may read" do
    assert Hass.config_key("Velvety", "apollos_a7_gtfs_2") == "Velvety.ha.device.apollos_a7_gtfs_2.config"
  end

  test "every config encodes" do
    for {_, d} <- devices(board()), do: assert({:ok, _} = Jason.encode(d))
  end
end
