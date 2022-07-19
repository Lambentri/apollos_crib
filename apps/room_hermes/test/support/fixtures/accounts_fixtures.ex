defmodule RoomHermes.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RoomHermes.Accounts` context.
  """

  @doc """
  Generate a rabbit_user.
  """
  def rabbit_user_fixture(attrs \\ %{}) do
    {:ok, rabbit_user} =
      attrs
      |> Enum.into(
           %{
             password: "some password",
             username: "some username"
           }
         )
      |> RoomHermes.Accounts.create_rabbit_user()

    rabbit_user
  end
end
