defmodule RoomSanctum.PlaniCompassTest do
  use ExUnit.Case, async: true

  alias RoomSanctum.Worker.Plani

  # Davis Square, give or take.
  @anchor %Geo.Point{coordinates: {-71.10, 42.39}, srid: 4326}

  test "the cardinals come out where they should" do
    assert Plani.compass(@anchor, 42.40, -71.10) == "N"
    assert Plani.compass(@anchor, 42.39, -71.09) == "E"
    assert Plani.compass(@anchor, 42.38, -71.10) == "S"
    assert Plani.compass(@anchor, 42.39, -71.11) == "W"
  end

  test "the diagonals account for a degree of longitude being shorter up here" do
    # A naive atan2 of the raw degree differences would call this NNE: at this
    # latitude a degree of longitude is about three quarters of a degree of
    # latitude, so equal *degrees* is not equal *distance*.
    assert Plani.compass(@anchor, 42.395, -71.0932) == "NE"
  end

  test "standing on the thing has no direction" do
    # atan2(0, 0) is zero, so without this the nearest bike of all would be
    # confidently reported as due north.
    assert Plani.compass(@anchor, 42.3900, -71.1000) == nil
    assert Plani.compass(@anchor, 42.39005, -71.10005) == nil
  end

  test "a row with no coordinates gets no direction rather than raising" do
    assert Plani.compass(@anchor, nil, nil) == nil
    assert Plani.compass(nil, 42.39, -71.10) == nil
  end
end
