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
  The source row on its own, without the associations `get_source!/1` brings.

  Those preloads are right for the pages that list a source's mailboxes and
  webhooks, and are two wasted queries everywhere else -- which includes the
  arrival lookup, where the only thing wanted is the config blob and the cost
  is paid on every call.
  """
  def get_source!(:bare, id), do: Repo.get!(Source, id)

  @doc """
  Subscribe to config changes for one record, so a worker can be told rather
  than asking.

  Every worker used to re-read its own config row on a two-to-four second
  timer, which is how a handful of sources kept a ten-connection pool
  saturated: those short reads queued behind the long arrival joins, a
  checkout timed out, the GenServer died, its supervisor restarted it, and the
  VM eventually went down on restart intensity.

  Nothing about that config changes on a timer. It changes when somebody edits
  it, in this application, in a process that can simply say so. The timers
  remain as a slow backstop for a write that never reaches this function -- a
  migration, or a hand at a psql prompt -- rather than as the way news travels.
  """
  def subscribe(kind, id) do
    Phoenix.PubSub.subscribe(RoomSanctum.PubSub, cfg_topic(kind, id))
  end

  defp cfg_topic(kind, id), do: "cfg:#{kind}:#{id}"

  # Only a write that actually landed is worth announcing.
  defp announce(result, kind)

  defp announce({:ok, record} = result, kind) do
    Phoenix.PubSub.broadcast(
      RoomSanctum.PubSub,
      cfg_topic(kind, record.id),
      {:cfg_changed, kind, record.id}
    )

    result
  end

  defp announce(result, _kind), do: result

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
    changeset = Source.changeset(source, attrs)

    changeset
    |> Repo.update()
    |> announce_source(changeset)
  end

  # `meta` is the workers' own bookkeeping -- last_run stamps, parcel tracking
  # -- written on a timer by the very workers that would be told about it.
  # Announcing those would have every worker re-read its config because one of
  # them finished a refresh, which is the loop this exists to remove.
  defp announce_source(result, changeset) do
    case Map.keys(changeset.changes) do
      [:meta] -> result
      _otherwise -> announce(result, :source)
    end
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

  @doc """
  Append a status entry to one tracked number.

  Every entry is converted to a plain map first. Replacing a single struct with a
  map left the rest as structs, which the embed cast rejects -- so this only ever
  worked while a source tracked exactly one parcel.
  """
  def update_source_meta_tracking(%Source{} = source, number, payload) do
    tracking = source.meta.tracking |> Enum.map(&Map.from_struct/1)

    case Enum.find_index(tracking, fn t -> t.number == number end) do
      nil ->
        {:error, :not_tracked}

      idx ->
        existing = Enum.at(tracking, idx)
        entries = (existing[:entries] || []) ++ [payload]
        updated = Map.put(existing, :entries, entries)

        update_source_meta(source, %{tracking: List.replace_at(tracking, idx, updated)})
    end
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
    source |> Repo.delete() |> announce(:source)
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
    from(v in Vision, where: ^id not in v.query_ids or is_nil(v.query_ids) or v.query_ids == []) |> Repo.all()
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
    |> announce(:vision)
  end

  def update_vision_ni(%Vision{} = vision, attrs) do
    vision
    |> Vision.changeset(attrs)
    |> Repo.update()
    |> announce(:vision)
  end

  # The form submits its queries as an index-keyed map and each one needs an id
  # to survive the round trip. Anything else -- an update that only touches the
  # name, or the tint -- has no queries to renumber and used to die on
  # `nil |> Enum.map`.
  defp inj_fake_ids(%{"queries" => queries} = attrs) when is_map(queries) or is_list(queries) do
    Map.put(attrs, "queries", Enum.map(queries, fn {ctr, val} -> Map.put(val, "id", ctr) end))
  end

  defp inj_fake_ids(attrs), do: attrs

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
  Where a query is being asked from.

  Every query that is answered *at* a place rather than near one names a foci,
  and resolves it the same way. A Plani asks the same questions from wherever
  its client is, which is not a foci and has no row to look up -- so it hands
  the place over directly, and this prefers it.

  One helper rather than each worker growing its own branch: they all did the
  same two lines, and a Plani that could relocate five of six sources would be
  worse than one that could relocate none.
  """
  def place_for!(%{place: %Geo.Point{} = place}), do: place

  def place_for!(%{foci_id: foci_id}) when not is_nil(foci_id) do
    get_foci!(foci_id).place
  end

  def place_for!(_query), do: nil

  @doc """
  What to call where a query is being asked from.

  The foci's name where there is one. A Plani asking from a client's position
  has no foci and no name for it, so it says what it is -- a board that reads
  "Here" is telling the truth about an anchor that moves.
  """
  def place_name(%{place: %Geo.Point{}}), do: "Here"

  def place_name(%{foci_id: foci_id}) when not is_nil(foci_id) do
    get_foci!(foci_id).name
  end

  def place_name(_query), do: "Here"

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

  alias RoomSanctum.Configuration.Plani

  @doc "Every Plani, for the supervisor that keeps a worker per one."
  def list_plani, do: Repo.all(Plani)

  def list_plani(uid), do: Repo.all(from p in Plani, where: p.user_id == ^uid)

  def get_plani!(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> get_plani!(n)
      _ -> raise Ecto.NoResultsError, queryable: Plani
    end
  end

  def get_plani!(id), do: Repo.get!(Plani, id)

  def create_plani(attrs \\ %{}) do
    %Plani{} |> Plani.changeset(attrs) |> Repo.insert() |> announce(:plani)
  end

  def update_plani(%Plani{} = plani, attrs) do
    plani |> Plani.changeset(attrs) |> Repo.update() |> announce(:plani)
  end

  def delete_plani(%Plani{} = plani), do: Repo.delete(plani)

  def change_plani(%Plani{} = plani, attrs \\ %{}), do: Plani.changeset(plani, attrs)

  @doc """
  The Pythiae on the other end of something.

  `:ankyra` is the reverse of the list a Pythiae carries -- a client's request
  arrives on a topic, and what has to act on it is whatever publishes there.
  `:plani` is the reverse of `curr_plani`: a Plani is worth nothing on its own,
  and the first question about one is which board it is driving.
  """
  def list_pythiae(:plani, id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> list_pythiae(:plani, n)
      _ -> []
    end
  end

  def list_pythiae(:plani, id) do
    from(p in Pythiae, where: p.curr_plani == ^id) |> Repo.all()
  end

  # Every Pythiae that publishes to a given Ankyra: the reverse of the list a
  # Pythiae carries, for the Ankyra end. A client's request arrives on a topic,
  # which identifies the Ankyra, and what has to act on it is whatever
  # publishes there.
  def list_pythiae(:ankyra, id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> list_pythiae(:ankyra, n)
      _ -> []
    end
  end

  def list_pythiae(:ankyra, id) do
    from(p in Pythiae, where: ^id in p.ankyra) |> Repo.all()
  end

  def get_pythiae!(:name, name), do: Repo.get_by(Pythiae, name: name)

  def get_pythiae(:vision, id) do
    from(p in Pythiae, where: ^id in p.visions) |> Repo.all()
  end

  @doc """
  The pythiae a vision is *not* on -- the ones it could be added to.

  Scoped to the user, unlike its opposite number for visions
  (`get_visions_nv/2`), which lists every vision in the database regardless of
  who owns it. A pythiae is a screen on somebody's wall; offering to put your
  vision on one belonging to someone else is not a feature.
  """
  def get_pythiae_nv(:vision, id, user_id) do
    from(p in Pythiae,
      where:
        p.user_id == ^user_id and
          (^id not in p.visions or is_nil(p.visions) or p.visions == [])
    )
    |> Repo.all()
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
    |> announce(:pythiae)
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

  alias RoomSanctum.Configuration.ScribusResolution

  def list_scribus_resolutions({:user, uid}) do
    from(r in ScribusResolution, where: r.user_id == ^uid, order_by: [asc: r.name])
    |> Repo.all()
  end

  def get_scribus_resolution!(id), do: Repo.get!(ScribusResolution, id)

  def create_scribus_resolution(attrs \\ %{}) do
    %ScribusResolution{}
    |> ScribusResolution.changeset(attrs)
    |> Repo.insert()
  end

  def update_scribus_resolution(%ScribusResolution{} = res, attrs) do
    res
    |> ScribusResolution.changeset(attrs)
    |> Repo.update()
  end

  def delete_scribus_resolution(%ScribusResolution{} = res), do: Repo.delete(res)

  def change_scribus_resolution(%ScribusResolution{} = res, attrs \\ %{}) do
    ScribusResolution.changeset(res, attrs)
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

  alias RoomSanctum.Configuration.Keryx

  @doc """
  Returns the list of keryxiae.

  ## Examples

      iex> list_keryxiae()
      [%Keryx{}, ...]

  """
  def list_keryxiae do
    Repo.all(Keryx)
  end

  def list_keryxiae({:user, uid}) do
    Repo.all(from k in Keryx, where: k.user_id == ^uid)
  end

  @doc """
  Gets a single keryx.

  Raises `Ecto.NoResultsError` if the Keryx does not exist.

  ## Examples

      iex> get_keryx!(123)
      %Keryx{}

      iex> get_keryx!(456)
      ** (Ecto.NoResultsError)

  """
  def get_keryx!(id), do: Repo.get!(Keryx, id)

  @doc """
  Creates a keryx.

  ## Examples

      iex> create_keryx(%{field: value})
      {:ok, %Keryx{}}

      iex> create_keryx(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_keryx(attrs \\ %{}) do
    %Keryx{}
    |> Keryx.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a keryx.

  ## Examples

      iex> update_keryx(keryx, %{field: new_value})
      {:ok, %Keryx{}}

      iex> update_keryx(keryx, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_keryx(%Keryx{} = keryx, attrs) do
    keryx
    |> Keryx.changeset(attrs)
    |> Repo.update()
    |> announce(:keryx)
  end

  @doc """
  Deletes a keryx.

  ## Examples

      iex> delete_keryx(keryx)
      {:ok, %Keryx{}}

      iex> delete_keryx(keryx)
      {:error, %Ecto.Changeset{}}

  """
  def delete_keryx(%Keryx{} = keryx) do
    Repo.delete(keryx)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking keryx changes.

  ## Examples

      iex> change_keryx(keryx)
      %Ecto.Changeset{data: %Keryx{}}

  """
  def change_keryx(%Keryx{} = keryx, attrs \\ %{}) do
    Keryx.changeset(keryx, attrs)
  end
end
