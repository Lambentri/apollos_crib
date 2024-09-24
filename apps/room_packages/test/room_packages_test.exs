defmodule RoomPackagesTest do
  use ExUnit.Case
  doctest RoomPackages

  test "greets the world" do
    assert RoomPackages.hello() == :world
  end
end
