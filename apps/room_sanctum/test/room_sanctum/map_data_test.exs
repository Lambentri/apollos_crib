defmodule RoomSanctumWeb.Live.Helpers.MapDataTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.Storage.AirNow.HourlyObsData
  alias RoomSanctum.Storage.GBFS.V1.FreeBikeStatus
  alias RoomSanctumWeb.Live.Helpers.MapData

  defp bike(id, opts \\ []) do
    %FreeBikeStatus{
      bike_id: id,
      lat: 37.75,
      lon: -122.41,
      is_disabled: Keyword.get(opts, :disabled, false),
      is_reserved: false,
      current_range_meters: Keyword.get(opts, :range, 12_000.0),
      vehicle_type_id: "scooter"
    }
  end

  describe "aircraft/1" do
    test "reads aircraft out of an icarus query's slot and leaves the rest alone" do
      preview = %{
        {1, :icarus} => [%{"hex" => "a1", "lat" => 42.0, "lon" => -71.0}],
        {2, :gtfs} => [%{something: :else}]
      }

      assert [%{"hex" => "a1"}] = MapData.aircraft(preview)
    end

    test "a flight watch carries its position one level down" do
      preview = %{
        {1, :icarus} => [%{"kind" => "flight", "position" => %{"lat" => 1.0, "lon" => 2.0}}]
      }

      assert [%{"lat" => 1.0, "lon" => 2.0}] = MapData.aircraft(preview)
    end

    test "nothing to read is not an error" do
      assert MapData.aircraft(nil) == []
      assert MapData.aircraft(%{}) == []
      assert MapData.aircraft(%{{1, :icarus} => []}) == []
    end
  end

  describe "free_bikes/1" do
    test "an area query's loose bikes are picked out; a station's answer is not" do
      preview = %{
        {1, :gbfs} => [bike("b1"), bike("b2")],
        # What a station query answers with: a dock, which is already on the
        # map as the query's own marker.
        {2, :gbfs} => [%{station_id: "s1", name: "Dock"}]
      }

      assert [%{bike_id: "b1"}, %{bike_id: "b2"}] = MapData.free_bikes(preview)
    end

    test "nothing to read is not an error" do
      assert MapData.free_bikes(nil) == []
      assert MapData.free_bikes(%{{1, :gbfs} => []}) == []
    end
  end

  describe "summaries/1 iconography" do
    test "a gtfs row keeps its route in words and marks the time as live or scheduled" do
      # The route and where it is going are the data; the glyph says which kind
      # of time is being quoted, exactly as the preview card does.
      # What the gtfs worker answers with, which is what the condenser reads.
      arrival = %{
        arrival_time: "17:04",
        arrival_time_live_ts: nil,
        tz: "America/New_York",
        trip: %{
          trip_headsign: "Watertown",
          route_id: "71",
          direction: %{direction: "Outbound"},
          route: %{route_type: 3}
        }
      }

      preview = %{{3, :gtfs} => [arrival]}

      assert %{3 => [line]} = MapData.summaries(preview)
      assert line.label == "71 to Watertown"
      assert line.value_icon == "clock"
      refute Map.has_key?(line, :icon)
    end
  end

  describe "stations/1" do
    test "docks from an area query are picked out; loose bikes are not" do
      preview = %{
        {1, :gbfs} => [
          bike("b1"),
          %{station_id: "s1", name: "22nd St", lat: 37.75, lon: -122.39, place: nil}
        ]
      }

      assert [%{station_id: "s1"}] = MapData.stations(preview)
    end

    test "a station id the feed never mentioned has nowhere to draw" do
      preview = %{{1, :gbfs} => [%{station_id: "ghost", place: nil, lat: nil}]}

      assert MapData.stations(preview) == []
    end

    test "nothing to read is not an error" do
      assert MapData.stations(nil) == []
      assert MapData.stations(%{{1, :gbfs} => []}) == []
    end
  end

  describe "summaries/1" do
    test "an area query counts its bikes rather than naming them" do
      preview = %{{9, :gbfs} => [bike("b1"), bike("b2", range: 30_000.0), bike("b3", disabled: true)]}

      assert %{9 => lines} = MapData.summaries(preview)
      assert %{icon: "bicycle", label: "Free bikes", value: "2 nearby"} in lines
      assert %{icon: "road", label: "Best range", value: "30.0 km"} in lines
    end

    test "an area query asked for docks counts those too" do
      preview = %{
        {9, :gbfs} => [
          bike("b1"),
          %{station_id: "s1", name: "22nd St", num_bikes_available: 13, num_ebikes_available: 10,
            num_docks_available: 21, num_docks_disabled: 0, capacity: 35, ebikes_info: []}
        ]
      }

      assert %{9 => lines} = MapData.summaries(preview)
      assert %{icon: "bicycle", label: "Free bikes", value: "1 nearby"} in lines
      assert %{icon: "square-parking", label: "Docks", value: "13 bikes at 1"} in lines
    end

    test "air quality shows the readings the card shows, under the names it uses" do
      obs = %HourlyObsData{
        reporting_areas: ["Mission"],
        ozone_measured: true,
        ozone_aqi: 31,
        pm25_measured: true,
        pm25_aqi: 44
      }

      assert %{7 => lines} = MapData.summaries(%{{7, :aqi} => [obs]})
      # The card labels air quality with a pair of lungs; the popup does too,
      # and the readings keep their own names because "PM2.5" is the data.
      assert %{icon: "lungs", label: "Station", value: "Mission"} in lines
      assert %{label: "PM2.5", value: "44"} in lines
      assert %{label: "O3", value: "31"} in lines
    end

    test "a type with no formatter of its own still says something" do
      preview = %{{8, :packages} => [%{carrier: "USPS", status: "In transit"}]}

      assert %{8 => lines} = MapData.summaries(preview)
      assert %{label: "Carrier", value: "USPS"} in lines
      assert %{label: "Status", value: "In transit"} in lines
    end

    test "capped, because this is a popup rather than the card" do
      entries = for i <- 1..10, do: %{a: "1#{i}", b: "2#{i}", c: "3#{i}"}

      assert %{4 => lines} = MapData.summaries(%{{4, :packages} => entries})
      assert length(lines) == 4
    end

    test "blank values are dropped rather than shown empty" do
      assert %{5 => []} = MapData.summaries(%{{5, :packages} => [%{carrier: nil, status: ""}]})
    end

    test "a shape the condenser cannot read costs that marker its lines, not the map" do
      assert %{2 => []} = MapData.summaries(%{{2, :weather} => [%{unexpected: true}]})
      assert %{1 => []} = MapData.summaries(%{{1, :gtfs} => []})
      assert MapData.summaries(nil) == %{}
    end

    test "summaries/2 keys a single query's own preview by its id" do
      query = %{id: 12, source: %{type: :gbfs}}

      assert %{12 => [%{label: "Free bikes", value: "1 nearby"} | _]} =
               MapData.summaries(query, [bike("b1")])
    end
  end
end
