defmodule RoomHermes.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias RoomHermes.Repo

  alias RoomHermes.Accounts.RabbitUser

  @doc """
  Returns the list of users_rabbit.

  ## Examples

      iex> list_users_rabbit()
      [%RabbitUser{}, ...]

  """
  def list_users_rabbit do
    Repo.all(RabbitUser)
  end

  def list_users_rabbit({:user, uid}) do
    Repo.all(from r in RabbitUser, where: r.user_id == ^uid)
  end

  @doc """
  Gets a single rabbit_user.

  Raises `Ecto.NoResultsError` if the Rabbit user does not exist.

  ## Examples

      iex> get_rabbit_user!(123)
      %RabbitUser{}

      iex> get_rabbit_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rabbit_user!(id), do: Repo.get!(RabbitUser, id)

  @doc """
  Creates a rabbit_user.

  ## Examples

      iex> create_rabbit_user(%{field: value})
      {:ok, %RabbitUser{}}

      iex> create_rabbit_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rabbit_user(attrs \\ %{}) do
    %RabbitUser{}
    |> RabbitUser.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a rabbit_user.

  ## Examples

      iex> update_rabbit_user(rabbit_user, %{field: new_value})
      {:ok, %RabbitUser{}}

      iex> update_rabbit_user(rabbit_user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rabbit_user(%RabbitUser{} = rabbit_user, attrs) do
    rabbit_user
    |> RabbitUser.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a rabbit_user.

  ## Examples

      iex> delete_rabbit_user(rabbit_user)
      {:ok, %RabbitUser{}}

      iex> delete_rabbit_user(rabbit_user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rabbit_user(%RabbitUser{} = rabbit_user) do
    Repo.delete(rabbit_user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rabbit_user changes.

  ## Examples

      iex> change_rabbit_user(rabbit_user)
      %Ecto.Changeset{data: %RabbitUser{}}

  """
  def change_rabbit_user(%RabbitUser{} = rabbit_user, attrs \\ %{}) do
    RabbitUser.changeset(rabbit_user, attrs)
  end

  def find_rabbit_user(username) do
    from(r in RabbitUser, where: r.username == ^username) |> Repo.one
  end

  def find_rabbit_user(username, password) do
    from(r in RabbitUser, where: r.username == ^username and r.password == ^password) |> Repo.one
  end
end
