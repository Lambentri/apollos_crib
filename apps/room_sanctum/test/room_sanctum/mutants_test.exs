defmodule RoomSanctum.MutantsTest do
  use ExUnit.Case, async: true
  doctest RoomSanctum.Mutants

  alias RoomSanctum.Mutants

  test "label_for/1 makes an operator-valid label" do
    assert Mutants.label_for("PineNote H") == "pinenote-h"
    assert Mutants.label_for("--Radxa 8\" HD--") == "radxa-8-hd"
    assert Mutants.label_for("!!!") == ""
    assert String.length(Mutants.label_for(String.duplicate("a", 80))) == 63
  end

  test "scale_resolution/2 stays between 1 and max_snappers before calling the operator" do
    assert {:error, _} = Mutants.scale_resolution("pinenote-v", 0)
    assert {:error, _} = Mutants.scale_resolution("pinenote-v", Mutants.max_snappers() + 1)
    assert {:error, _} = Mutants.scale_resolution("pinenote-v", "2")
  end

  test "create_resolution/4 validates before calling the operator" do
    assert {:error, _} = Mutants.create_resolution("!!!", 10, 10)
    assert {:error, _} = Mutants.create_resolution("ok", 0, 10)
  end
end
