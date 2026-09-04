defmodule RoomSanctum.PlaniGtfsRtTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.Condenser.BasicMQTT

  defp arrival(route) do
    %{
      arrival_time: "08:00:00",
      arrival_time_live_ts: nil,
      tz: "America/New_York",
      trip_id: "t1",
      trip: %{
        trip_headsign: "Arlington",
        direction: %{direction: "In"},
        route_id: route,
        route: %{
          route_type: "3",
          route_short_name: route,
          route_long_name: route,
          route_color: nil,
          route_text_color: nil
        }
      }
    }
  end

  test "a broken out entry names its source so alerts can be looked up" do
    # The entry's own id is source-and-stop, which is not a source id -- so the
    # alerts lookup found nothing for every broken out stop, and silently: no
    # alerts and no such source look identical from the condenser.
    descriptor = %{
      id: "40:2378",
      name: "Boston Ave @ College Ave",
      meta: %{},
      query: %{source_id: 40, stop: "2378"}
    }

    out = BasicMQTT.condense({"40:2378", :gtfs}, [arrival("96")], descriptor)

    assert out.query.name == "Boston Ave @ College Ave"
    assert [%{route: "96"}] = out.data
  end

  test "a vision's entry still resolves alerts from the entry id" do
    # No source_id in the descriptor: the id *is* the source there, and that
    # path must keep working exactly as it did.
    vision = %{id: 12, name: "Forest Hills", meta: %{}, query: %{stop: "10642"}}

    out = BasicMQTT.condense({12, :gtfs}, [arrival("14")], vision)

    assert out.query.name == "Forest Hills"
    assert [%{route: "14"}] = out.data
  end
end
