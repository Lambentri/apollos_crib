defmodule RoomSanctum.Configuration do
  @moduledoc """
  The Configuration context.
  """

  import Ecto.Query, warn: false
  alias RoomSanctum.Repo

  alias RoomSanctum.Configuration.Source

  @doc """
  Returns the list of cfg_sources.

  ## Examples

      iex> list_cfg_sources()
      [%Source{}, ...]

  """
  def list_cfg_sources do
    Repo.all(Source)
  end

  def list_cfg_sources({:type, type}) do
    Repo.all(from s in Source, where: s.type == ^type)
  end

  def list_cfg_sources({:user, uid}) do
    Repo.all(from s in Source, where: s.user_id == ^uid)
  end

  @doc """
  Gets a single source.

  Raises `Ecto.NoResultsError` if the Source does not exist.

  ## Examples

      iex> get_source!(123)
      %Source{}

      iex> get_source!(456)
      ** (Ecto.NoResultsError)

  """
  def get_source!(id), do: Repo.get!(Source, id)

  @doc """
  Creates a source.

  ## Examples

      iex> create_source(%{field: value})
      {:ok, %Source{}}

      iex> create_source(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_source(attrs \\ %{}) do
    %Source{}
    |> Source.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a source.

  ## Examples

      iex> update_source(source, %{field: new_value})
      {:ok, %Source{}}

      iex> update_source(source, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_source(%Source{} = source, attrs) do
    source
    |> Source.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a source.

  ## Examples

      iex> delete_source(source)
      {:ok, %Source{}}

      iex> delete_source(source)
      {:error, %Ecto.Changeset{}}

  """
  def delete_source(%Source{} = source) do
    Repo.delete(source)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking source changes.

  ## Examples

      iex> change_source(source)
      %Ecto.Changeset{data: %Source{}}

  """
  def change_source(%Source{} = source, attrs \\ %{}) do
    Source.changeset(source, attrs)
  end

  def toggle_source!(id, tgt) do
    src = get_source!(id)
    update_source(src, %{enabled: tgt})
  end

  alias RoomSanctum.Configuration.Query

  @doc """
  Returns the list of cfg_queries.

  ## Examples

      iex> list_cfg_queries()
      [%Query{}, ...]

  """
  def list_cfg_queries do
    Repo.all(from q in Query, preload: [:source])
  end

  def list_cfg_queries({:user, uid}) do
    Repo.all(from q in Query, where: q.user_id == ^uid, preload: [:source])
  end

  @doc """
  Gets a single query.

  Raises `Ecto.NoResultsError` if the Query does not exist.

  ## Examples

      iex> get_query!(123)
      %Query{}

      iex> get_query!(456)
      ** (Ecto.NoResultsError)

  """
  def get_query!(id), do: Repo.get!(Query, id) |> Repo.preload(:source)

  def get_queries!(ids) do
    from( q in Query, where: q.id in ^ids) |> Repo.all |> Repo.preload(:source)
  end

  def get_queries(:source, id) do
    from(q in Query, where: q.source_id == ^id) |> Repo.all |> Repo.preload(:source)
  end

  @doc """
  Creates a query.

  ## Examples

      iex> create_query(%{field: value})
      {:ok, %Query{}}

      iex> create_query(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_query(attrs \\ %{}) do
    %Query{}
    |> Query.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a query.

  ## Examples

      iex> update_query(query, %{field: new_value})
      {:ok, %Query{}}

      iex> update_query(query, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_query(%Query{} = query, attrs) do
    query
    |> Query.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a query.

  ## Examples

      iex> delete_query(query)
      {:ok, %Query{}}

      iex> delete_query(query)
      {:error, %Ecto.Changeset{}}

  """
  def delete_query(%Query{} = query) do
    Repo.delete(query)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking query changes.

  ## Examples

      iex> change_query(query)
      %Ecto.Changeset{data: %Query{}}

  """
  def change_query(%Query{} = query, attrs \\ %{}) do
    Query.changeset(query, attrs)
  end

  alias RoomSanctum.Configuration.Vision

  @doc """
  Returns the list of visions.

  ## Examples

      iex> list_visions()
      [%Vision{}, ...]

  """
  def list_visions do
    Repo.all(Vision)
  end

  def list_visions({:user, uid}) do
    Repo.all(from s in Vision, where: s.user_id == ^uid)
  end

  @doc """
  Gets a single vision.

  Raises `Ecto.NoResultsError` if the Vision does not exist.

  ## Examples

      iex> get_vision!(123)
      %Vision{}

      iex> get_vision!(456)
      ** (Ecto.NoResultsError)

  """
  def get_vision!(id), do: Repo.get!(Vision, id)

  def get_vision(id), do: Repo.get(Vision, id)

  def get_visions(:query, id) do
    from(v in Vision, where: ^id in v.query_ids) |> Repo.all
  end

  @doc """
  Creates a vision.

  ## Examples

      iex> create_vision(%{field: value})
      {:ok, %Vision{}}

      iex> create_vision(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_vision(attrs \\ %{}) do
    %Vision{}
    |> Vision.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a vision.

  ## Examples

      iex> update_vision(vision, %{field: new_value})
      {:ok, %Vision{}}

      iex> update_vision(vision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_vision(%Vision{} = vision, attrs) do
    vision
    |> Vision.changeset(inj_fake_ids(attrs))
    |> Repo.update()
  end

  defp inj_fake_ids(attrs) do
    q = attrs["queries"] |> Enum.map(fn {ctr, val} -> val |> Map.put("id", ctr) end)
    Map.put(attrs, "queries", q)
  end

  @doc """
  Deletes a vision.

  ## Examples

      iex> delete_vision(vision)
      {:ok, %Vision{}}

      iex> delete_vision(vision)
      {:error, %Ecto.Changeset{}}

  """
  def delete_vision(%Vision{} = vision) do
    Repo.delete(vision)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking vision changes.

  ## Examples

      iex> change_vision(vision)
      %Ecto.Changeset{data: %Vision{}}

  """
  def change_vision(%Vision{} = vision, attrs \\ %{}) do
    Vision.changeset(vision, attrs)
  end

  #
  def get_landing_vision() do
    q = from v in Vision,
             where: v.public == true,
             order_by: fragment("RANDOM()"),
             limit: 1
    q
    |> Repo.one
  end


  alias RoomSanctum.Configuration.Foci

  @doc """
  Returns the list of focis.

  ## Examples

      iex> list_focis()
      [%Foci{}, ...]

  """
  def list_focis do
    Repo.all(Foci)
  end

  def list_focis({:user, uid}) do
    Repo.all(from q in Foci, where: q.user_id == ^uid)
  end

  @doc """
  Gets a single foci.

  Raises `Ecto.NoResultsError` if the Foci does not exist.

  ## Examples

      iex> get_foci!(123)
      %Foci{}

      iex> get_foci!(456)
      ** (Ecto.NoResultsError)

  """
  def get_foci!(id), do: Repo.get!(Foci, id)

  @doc """
  Creates a foci.

  ## Examples

      iex> create_foci(%{field: value})
      {:ok, %Foci{}}

      iex> create_foci(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_foci(attrs \\ %{}) do
    %Foci{}
    |> Foci.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a foci.

  ## Examples

      iex> update_foci(foci, %{field: new_value})
      {:ok, %Foci{}}

      iex> update_foci(foci, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_foci(%Foci{} = foci, attrs) do
    foci
    |> Foci.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a foci.

  ## Examples

      iex> delete_foci(foci)
      {:ok, %Foci{}}

      iex> delete_foci(foci)
      {:error, %Ecto.Changeset{}}

  """
  def delete_foci(%Foci{} = foci) do
    Repo.delete(foci)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking foci changes.

  ## Examples

      iex> change_foci(foci)
      %Ecto.Changeset{data: %Foci{}}

  """
  def change_foci(%Foci{} = foci, attrs \\ %{}) do
    Foci.changeset(foci, attrs)
  end

  alias RoomSanctum.Configuration.Pythiae

  @doc """
  Returns the list of cfg_pythiae.

  ## Examples

      iex> list_cfg_pythiae()
      [%Pythiae{}, ...]

  """
  def list_cfg_pythiae do
    Repo.all(Pythiae)
  end

  def list_cfg_pythiae({:user, uid}) do
    Repo.all(from s in Pythiae, where: s.user_id == ^uid)
  end

  @doc """
  Gets a single pythiae.

  Raises `Ecto.NoResultsError` if the Pythiae does not exist.

  ## Examples

      iex> get_pythiae!(123)
      %Pythiae{}

      iex> get_pythiae!(456)
      ** (Ecto.NoResultsError)

  """
  def get_pythiae!(id), do: Repo.get!(Pythiae, id)

  def get_pythiae!(:name, name), do: Repo.get_by(Pythiae, name: name)

  def get_pythiae(:vision, id) do
    from(p in Pythiae, where: ^id in p.visions) |> Repo.all
  end


  @doc """
  Creates a pythiae.

  ## Examples

      iex> create_pythiae(%{field: value})
      {:ok, %Pythiae{}}

      iex> create_pythiae(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_pythiae(attrs \\ %{}) do
    %Pythiae{}
    |> Pythiae.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a pythiae.

  ## Examples

      iex> update_pythiae(pythiae, %{field: new_value})
      {:ok, %Pythiae{}}

      iex> update_pythiae(pythiae, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_pythiae(%Pythiae{} = pythiae, attrs) do
    pythiae
    |> Pythiae.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a pythiae.

  ## Examples

      iex> delete_pythiae(pythiae)
      {:ok, %Pythiae{}}

      iex> delete_pythiae(pythiae)
      {:error, %Ecto.Changeset{}}

  """
  def delete_pythiae(%Pythiae{} = pythiae) do
    Repo.delete(pythiae)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking pythiae changes.

  ## Examples

      iex> change_pythiae(pythiae)
      %Ecto.Changeset{data: %Pythiae{}}

  """
  def change_pythiae(%Pythiae{} = pythiae, attrs \\ %{}) do
    Pythiae.changeset(pythiae, attrs)
  end
end
