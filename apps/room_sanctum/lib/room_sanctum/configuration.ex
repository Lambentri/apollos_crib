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
  def get_source!(id), do: Repo.get!(Source, id) |> Repo.preload([:mailboxes, :webhooks])

  @doc """
  Creates a source.

  ## Examples

      iex> create_source(%{field: value})
      {:ok, %Source{}}

      iex> create_source(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_source(attrs \\ %{}) do
    r = %Source{} |> Source.changeset(attrs) |> Repo.insert()
    {:ok, d} = r
    case d.type do
      :packages ->
        ## create main mailbox
        create_taxid(%{source_id: d.id, user: Ecto.UUID.generate, designator: "mail_main"})
        ## create mailbox for usps handling
        create_taxid(%{source_id: d.id, user: Ecto.UUID.generate, designator: "mail_usps"})

        ## create default webhook url
        create_agyr(%{source_id: d.id, path: Ecto.UUID.generate, user: Ecto.UUID.generate, token: Ecto.UUID.generate, designator: "ups_webhook"})

      _otherwise ->
        :ok
    end

    r
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

  def update_source_config(%Source{} = source, attrs) do
    m = source.config |> Map.merge(attrs) |> Map.from_struct()
    update_source(source, %{config: m})
  end

  def update_source_meta(%Source{} = source, attrs) do
    m = source.meta |> Map.merge(attrs) |> Map.from_struct()
    update_source(source, %{meta: m})
  end

  def create_source_meta_tracking(%Source{} = source, number, type) do
    s = source.meta
    original_tracking = source.meta.tracking |> Enum.map(fn x -> Map.from_struct(x) end)
    extant_id = original_tracking |> Enum.filter(fn t -> t.number == number end)
    case length(extant_id) do
      0 -> new_entry = %{number: number, type: type, entries: []}
           new_tracking = List.insert_at(original_tracking, -1 ,new_entry)
           RoomSanctum.Configuration.update_source_meta(source, %{tracking: new_tracking})
           new_tracking
      _otherwise ->
          original_tracking
    end
  end

  def update_source_meta_tracking(%Source{} = source, number, payload) do
    s = source.meta
    original_tracking = source.meta.tracking
    {extant_id, idx} = original_tracking |> Enum.with_index |> Enum.filter(fn {t, _i} -> t.number == number end) |> List.first
    entries = extant_id |> Map.get(:entries)
    new_entries = entries |> List.insert_at(-1, payload)
    updated_id = extant_id |> Map.put(:entries, new_entries) |> Map.from_struct

    updated_tracking = original_tracking |> List.replace_at(idx, updated_id)
    RoomSanctum.Configuration.update_source_meta(source, %{tracking: updated_tracking})
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
    from(q in Query, where: q.id in ^ids) |> Repo.all() |> Repo.preload(:source)
  end

  def get_queries(:source, id) do
    from(q in Query, where: q.source_id == ^id) |> Repo.all() |> Repo.preload(:source)
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
    from(v in Vision, where: ^id in v.query_ids) |> Repo.all()
  end

  def get_visions_nv(:query, id) do
    from(v in Vision, where: ^id not in v.query_ids) |> Repo.all()
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

  def update_vision_ni(%Vision{} = vision, attrs) do
    vision
    |> Vision.changeset(attrs)
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
    q =
      from v in Vision,
        where: v.public == true,
        order_by: fragment("RANDOM()"),
        limit: 1

    q
    |> Repo.one()
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
    from(p in Pythiae, where: ^id in p.visions) |> Repo.all()
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

  alias RoomSanctum.Configuration.Scribus

  @doc """
  Returns the list of cfg_scribus.

  ## Examples

      iex> list_cfg_scribus()
      [%Scribus{}, ...]

  """
  def list_cfg_scribus do
    Repo.all(Scribus)
  end

  @doc """
  Gets a single scribus.

  Raises `Ecto.NoResultsError` if the Scribus does not exist.

  ## Examples

      iex> get_scribus!(123)
      %Scribus{}

      iex> get_scribus!(456)
      ** (Ecto.NoResultsError)

  """
  def get_scribus!(id), do: Repo.get!(Scribus, id)

  @doc """
  Creates a scribus.

  ## Examples

      iex> create_scribus(%{field: value})
      {:ok, %Scribus{}}

      iex> create_scribus(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_scribus(attrs \\ %{}) do
    %Scribus{}
    |> Scribus.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a scribus.

  ## Examples

      iex> update_scribus(scribus, %{field: new_value})
      {:ok, %Scribus{}}

      iex> update_scribus(scribus, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_scribus(%Scribus{} = scribus, attrs) do
    scribus
    |> Scribus.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a scribus.

  ## Examples

      iex> delete_scribus(scribus)
      {:ok, %Scribus{}}

      iex> delete_scribus(scribus)
      {:error, %Ecto.Changeset{}}

  """
  def delete_scribus(%Scribus{} = scribus) do
    Repo.delete(scribus)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking scribus changes.

  ## Examples

      iex> change_scribus(scribus)
      %Ecto.Changeset{data: %Scribus{}}

  """
  def change_scribus(%Scribus{} = scribus, attrs \\ %{}) do
    Scribus.changeset(scribus, attrs)
  end

  alias RoomSanctum.Configuration.Agyr

  @doc """
  Returns the list of cfg_webhooks.

  ## Examples

      iex> list_cfg_webhooks()
      [%Agyr{}, ...]

  """
  def list_cfg_webhooks do
    Repo.all(Agyr)
  end

  @doc """
  Gets a single agyr.

  Raises `Ecto.NoResultsError` if the Agyr does not exist.

  ## Examples

      iex> get_agyr!(123)
      %Agyr{}

      iex> get_agyr!(456)
      ** (Ecto.NoResultsError)

  """
  def get_agyr!(id), do: Repo.get!(Agyr, id)

  def get_agyr!(:src, src, des), do: Repo.get_by(Agyr, source_id: src, designator: des)

  def get_agyr!(:path, path), do: Repo.get_by(Agyr, path: path)

  @doc """
  Creates a agyr.

  ## Examples

      iex> create_agyr(%{field: value})
      {:ok, %Agyr{}}

      iex> create_agyr(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_agyr(attrs \\ %{}) do
    %Agyr{}
    |> Agyr.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a agyr.

  ## Examples

      iex> update_agyr(agyr, %{field: new_value})
      {:ok, %Agyr{}}

      iex> update_agyr(agyr, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_agyr(%Agyr{} = agyr, attrs) do
    agyr
    |> Agyr.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a agyr.

  ## Examples

      iex> delete_agyr(agyr)
      {:ok, %Agyr{}}

      iex> delete_agyr(agyr)
      {:error, %Ecto.Changeset{}}

  """
  def delete_agyr(%Agyr{} = agyr) do
    Repo.delete(agyr)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking agyr changes.

  ## Examples

      iex> change_agyr(agyr)
      %Ecto.Changeset{data: %Agyr{}}

  """
  def change_agyr(%Agyr{} = agyr, attrs \\ %{}) do
    Agyr.changeset(agyr, attrs)
  end

  alias RoomSanctum.Configuration.Taxid

  @doc """
  Returns the list of cfg_mailboxes.

  ## Examples

      iex> list_cfg_mailboxes()
      [%Taxid{}, ...]

  """
  def list_cfg_mailboxes do
    Repo.all(Taxid)
  end

  @doc """
  Gets a single taxid.

  Raises `Ecto.NoResultsError` if the Taxid does not exist.

  ## Examples

      iex> get_taxid!(123)
      %Taxid{}

      iex> get_taxid!(456)
      ** (Ecto.NoResultsError)

  """

  def get_taxid(:id, id), do: Repo.get(Taxid, id)
  def get_taxid(:user, id), do: Repo.get_by(Taxid, user: id)
  def get_taxid!(id), do: Repo.get!(Taxid, id)

  @doc """
  Creates a taxid.

  ## Examples

      iex> create_taxid(%{field: value})
      {:ok, %Taxid{}}

      iex> create_taxid(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_taxid(attrs \\ %{}) do
    %Taxid{}
    |> Taxid.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a taxid.

  ## Examples

      iex> update_taxid(taxid, %{field: new_value})
      {:ok, %Taxid{}}

      iex> update_taxid(taxid, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_taxid(%Taxid{} = taxid, attrs) do
    taxid
    |> Taxid.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a taxid.

  ## Examples

      iex> delete_taxid(taxid)
      {:ok, %Taxid{}}

      iex> delete_taxid(taxid)
      {:error, %Ecto.Changeset{}}

  """
  def delete_taxid(%Taxid{} = taxid) do
    Repo.delete(taxid)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking taxid changes.

  ## Examples

      iex> change_taxid(taxid)
      %Ecto.Changeset{data: %Taxid{}}

  """
  def change_taxid(%Taxid{} = taxid, attrs \\ %{}) do
    Taxid.changeset(taxid, attrs)
  end
end
