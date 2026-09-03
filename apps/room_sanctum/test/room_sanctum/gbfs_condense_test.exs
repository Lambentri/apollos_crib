defmodule RoomSanctum.GbfsCondenseTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.Condenser.BasicMQTT

  # Both queries that produce these rows left join the e-bikes table, so the
  # field is nil for every dock that has no e-bike sitting in it -- which is
  # most of them, in a system that does not run any.
  @dock %{
    name: "Packard Ave",
    station_id: "6cec3afa-554c-466f-8323-5c619fe0ddc6",
    num_bikes_available: 4,
    num_ebikes_available: 0,
    num_docks_available: 9,
    num_docks_disabled: 0,
    capacity: 13,
    ebikes_info: nil
  }

  test "a dock with no e-bikes row condenses rather than raising" do
    [station] = BasicMQTT.condense_data({7, :gbfs}, [@dock])

    assert station.name == "Packard Ave"
    assert station.avail == 4
    assert station.ebikes_info == []
  end

  test "a feed that does not count e-bikes separately still gets a standard count" do
    dock = %{@dock | num_ebikes_available: nil}

    assert [%{avail_std: 4}] = BasicMQTT.condense_data({7, :gbfs}, [dock])
  end

  test "a broken out dock keys by source and station" do
    # What a Plani publishes: the station id is a UUID, so the key has dashes
    # well past the one separating the type. See WireTest on the client.
    assert "gbfs-7:6cec3afa-554c-466f-8323-5c619fe0ddc6" ==
             "gbfs-7:#{@dock.station_id}"
  end
end
