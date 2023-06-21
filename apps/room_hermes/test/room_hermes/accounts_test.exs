defmodule RoomHermes.AccountsTest do
  use RoomHermes.DataCase

  alias RoomHermes.Accounts

  describe "users_rabbit" do
    alias RoomHermes.Accounts.RabbitUser

    import RoomHermes.AccountsFixtures

    @invalid_attrs %{password: nil, username: nil}

    test "list_users_rabbit/0 returns all users_rabbit" do
      rabbit_user = rabbit_user_fixture()
      assert Accounts.list_users_rabbit() == [rabbit_user]
    end

    test "get_rabbit_user!/1 returns the rabbit_user with given id" do
      rabbit_user = rabbit_user_fixture()
      assert Accounts.get_rabbit_user!(rabbit_user.id) == rabbit_user
    end

    test "create_rabbit_user/1 with valid data creates a rabbit_user" do
      valid_attrs = %{password: "some password", username: "some username"}

      assert {:ok, %RabbitUser{} = rabbit_user} = Accounts.create_rabbit_user(valid_attrs)
      assert rabbit_user.password == "some password"
      assert rabbit_user.username == "some username"
    end

    test "create_rabbit_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_rabbit_user(@invalid_attrs)
    end

    test "update_rabbit_user/2 with valid data updates the rabbit_user" do
      rabbit_user = rabbit_user_fixture()
      update_attrs = %{password: "some updated password", username: "some updated username"}

      assert {:ok, %RabbitUser{} = rabbit_user} =
               Accounts.update_rabbit_user(rabbit_user, update_attrs)

      assert rabbit_user.password == "some updated password"
      assert rabbit_user.username == "some updated username"
    end

    test "update_rabbit_user/2 with invalid data returns error changeset" do
      rabbit_user = rabbit_user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_rabbit_user(rabbit_user, @invalid_attrs)

      assert rabbit_user == Accounts.get_rabbit_user!(rabbit_user.id)
    end

    test "delete_rabbit_user/1 deletes the rabbit_user" do
      rabbit_user = rabbit_user_fixture()
      assert {:ok, %RabbitUser{}} = Accounts.delete_rabbit_user(rabbit_user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_rabbit_user!(rabbit_user.id) end
    end

    test "change_rabbit_user/1 returns a rabbit_user changeset" do
      rabbit_user = rabbit_user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_rabbit_user(rabbit_user)
    end
  end
end
