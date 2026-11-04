defmodule RoomSanctum.DeleteRabbitUserTest do
  @moduledoc """
  Deleting an Ankyra -- a rabbit user -- removes its row, which is all the
  broker knows it by: RabbitMQ asks room_hermes's HTTP auth backend, which
  reads this table, and nothing is provisioned on the broker itself. Its
  worker, re-reading a row that is gone, stops and stays stopped.
  """
  use RoomSanctum.DataCase

  import RoomSanctum.OwnershipFixtures

  alias RoomSanctum.{Accounts, Repo}
  alias RoomSanctum.Worker.Ankyra

  setup :users_rabbit!

  test "delete_rabbit_user!/1 removes the row and returns it" do
    ankyra = ankyra_for(owner())

    assert %Accounts.RabbitUser{id: id} = Accounts.delete_rabbit_user!(ankyra)
    assert id == ankyra.id
    refute Repo.reload(ankyra)
    refute Accounts.find_rabbit_user(ankyra.username, ankyra.password)
  end

  test "delete_rabbit_user!/1 raises when there is nothing left to delete" do
    ankyra = ankyra_for(owner())
    {:ok, _} = Accounts.delete_rabbit_user(ankyra)

    assert_raise Ecto.StaleEntryError, fn -> Accounts.delete_rabbit_user!(ankyra) end
  end

  test "delete_rabbit_user/1 removes the row" do
    ankyra = ankyra_for(owner())

    assert {:ok, _} = Accounts.delete_rabbit_user(ankyra)
    refute Repo.reload(ankyra)
  end

  test "a worker whose rabbit user is gone stops normally, and is not restarted" do
    ankyra = ankyra_for(owner())
    {:ok, _} = Accounts.delete_rabbit_user(ankyra)
    state = %{id: to_string(ankyra.id), ankyra: ankyra, requests: nil}

    assert {:stop, :normal, _state} = Ankyra.handle_cast(:refresh_db_cfg, state)
    assert %{restart: :transient} = Ankyra.child_spec(id: "1")
  end
end
