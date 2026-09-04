defmodule RoomGbfs.V3Test do
  use ExUnit.Case, async: true

  alias RoomGbfs.V3

  describe "discovery" do
    test "v2 keys its feeds by language" do
      body = %{
        "data" => %{
          "en" => %{"feeds" => [%{"name" => "station_status", "url" => "http://x/ss"}]},
          "fr" => %{"feeds" => []}
        }
      }

      assert {:ok, :v2, [%{"name" => "station_status"}]} = V3.feeds(body, "en")
    end

    test "v3 does not, and is told apart by that" do
      # Shape rather than the version string: this is what actually has to be
      # true for the parse to work.
      body = %{
        "version" => "3.0",
        "data" => %{"feeds" => [%{"name" => "vehicle_status", "url" => "http://x/vs"}]}
      }

      assert {:ok, :v3, [%{"name" => "vehicle_status"}]} = V3.feeds(body, "en")
    end

    test "a v2 feed missing the configured language reports what it does have" do
      body = %{"data" => %{"ca" => %{"feeds" => []}, "es" => %{"feeds" => []}}}

      assert {:error, languages} = V3.feeds(body, "en")
      assert Enum.sort(languages) == ["ca", "es"]
    end

    test "a body that is not a discovery document does not raise" do
      assert {:error, []} = V3.feeds(%{}, "en")
      assert {:error, []} = V3.feeds(%{"data" => nil}, "en")
    end
  end

  describe "feed names" do
    test "v3's vehicle_status is v2's free_bike_status" do
      assert V3.feed_name("vehicle_status") == "free_bike_status"
    end

    test "everything else keeps its name" do
      assert V3.feed_name("station_status") == "station_status"
    end
  end

  describe "station status" do
    test "v3 counts vehicles where v2 counted bikes" do
      row = %{station_id: "1", num_vehicles_available: 7, num_vehicles_disabled: 2}

      assert %{num_bikes_available: 7, num_bikes_disabled: 2} = V3.station_status(row)
    end

    test "a v2 row passes through untouched" do
      row = %{station_id: "1", num_bikes_available: 4, num_bikes_disabled: 0}

      assert V3.station_status(row) == row
    end

    test "the v3 key does not survive the rename" do
      # It would be cast away anyway, but leaving it invites a reader to think
      # both names are live.
      refute Map.has_key?(V3.station_status(%{num_vehicles_available: 3}), :num_vehicles_available)
    end
  end

  describe "the electric count v3 dropped" do
    # PBSC's Chattanooga fleet, as it actually publishes it.
    defp types do
      %{
        "ICONIC" => %{propulsion_type: "human"},
        "FIT" => %{propulsion_type: "human"},
        "EFIT" => %{propulsion_type: "electric_assist"},
        "CHLOE" => %{propulsion_type: "electric"},
        "CAR" => %{propulsion_type: "combustion"}
      }
    end

    test "assist and full electric count, combustion does not" do
      assert Enum.sort(RoomGbfs.V3.electric_type_ids(types())) == ["CHLOE", "EFIT"]
    end

    test "the electric ones at a station are added back up" do
      # Two human bikes and one assist: three available, one of them electric.
      row = %{
        num_vehicles_available: 3,
        vehicle_types_available: [
          %{vehicle_type_id: "ICONIC", count: 2},
          %{vehicle_type_id: "EFIT", count: 1},
          %{vehicle_type_id: "CHLOE", count: 0}
        ]
      }

      out = V3.station_status(row, V3.electric_type_ids(types()))

      assert out.num_bikes_available == 3
      assert out.num_ebikes_available == 1
    end

    test "a feed that already reports the count keeps its own" do
      # Lyft publishes this as an extension; theirs is authoritative over
      # anything worked out from the type breakdown.
      row = %{
        num_bikes_available: 5,
        num_ebikes_available: 4,
        vehicle_types_available: [%{vehicle_type_id: "EFIT", count: 1}]
      }

      assert %{num_ebikes_available: 4} = V3.station_status(row, V3.electric_type_ids(types()))
    end

    test "no types loaded yet means no invented number" do
      row = %{num_vehicles_available: 3, vehicle_types_available: [%{vehicle_type_id: "EFIT", count: 1}]}

      refute Map.has_key?(V3.station_status(row, nil), :num_ebikes_available)
    end

    test "a station with no breakdown is left alone" do
      refute Map.has_key?(
               V3.station_status(%{num_vehicles_available: 3}, V3.electric_type_ids(types())),
               :num_ebikes_available
             )
    end
  end

  describe "feed order" do
    test "vehicle types are read before anything that needs them" do
      feeds = [
        %{"name" => "station_status"},
        %{"name" => "vehicle_types"},
        %{"name" => "station_information"}
      ]

      assert [%{"name" => "vehicle_types"} | _] = Enum.sort_by(feeds, &V3.feed_order/1)
    end
  end

  describe "loose vehicles" do
    test "v3's vehicle_id is v2's bike_id" do
      assert %{bike_id: "b1"} = V3.vehicle_status(%{vehicle_id: "b1", lat: 1.0, lon: 2.0})
    end

    test "a v2 row passes through untouched" do
      row = %{bike_id: "b1", lat: 1.0, lon: 2.0}
      assert V3.vehicle_status(row) == row
    end
  end

  describe "localised text" do
    test "the configured language wins" do
      value = [%{text: "Bicing", language: "ca"}, %{text: "Bicing ES", language: "es"}]

      assert V3.text(value, "es") == "Bicing ES"
    end

    test "a feed that does not carry that language still gives a name" do
      # Wrong language beats no name at all.
      value = [%{text: "Bicing", language: "ca"}]

      assert V3.text(value, "en") == "Bicing"
    end

    test "a v2 string is returned as it is" do
      assert V3.text("Packard Ave", "en") == "Packard Ave"
      assert V3.text(nil, "en") == nil
    end

    test "a station's name is localised in place" do
      row = %{station_id: "1", name: [%{text: "Plaça Espanya", language: "ca"}]}

      assert %{name: "Plaça Espanya", station_id: "1"} = V3.station_info(row, "ca")
    end

    test "a station with no short_name does not gain one" do
      refute Map.has_key?(V3.station_info(%{name: "X"}, "en"), :short_name)
    end
  end

  describe "system information" do
    test "v3's language list becomes the one language the schema holds" do
      row = %{system_id: "bicing", languages: ["ca", "es"], name: [%{text: "Bicing", language: "ca"}]}

      assert %{language: "ca", name: "Bicing"} = V3.system_information(row, "ca")
    end

    test "a v2 system is unchanged" do
      row = %{system_id: "bluebikes", language: "en", name: "Bluebikes", operator: "Lyft"}

      assert V3.system_information(row, "en") == row
    end
  end
end
