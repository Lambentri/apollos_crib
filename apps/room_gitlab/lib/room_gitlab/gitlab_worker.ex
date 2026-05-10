defmodule RoomGitlab.Worker do
  @moduledoc false
  use GenServer
  use Nebulex.Caching

  require Logger

  alias RoomSanctum.Configuration

  @ttl :timer.minutes(5)

  @registry :zeus
  @gitlab_config_module RoomSanctum.Configuration.Configs.Gitlab

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("gitlab" <> opts[:name]))
  end

  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(10),
      run: fn -> RoomGitlab.Worker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 0
    )

    Periodic.start_link(
      every: :timer.seconds(60 * 60 * 6),
      run: fn -> RoomGitlab.Worker.query_projects(opts[:name]) end,
      initial_delay: 2
    )

    Periodic.start_link(
      every: :timer.seconds(60 * 60),
      run: fn -> RoomGitlab.Worker.query_commits(opts[:name]) end,
      initial_delay: 8
    )

    # Jobs cadence is configurable per source via config.poll_seconds; self-reschedules.
    Process.send_after(self(), :tick_jobs, :timer.seconds(6))

    {:ok,
     %{
       id: opts[:name],
       inst: %{},
       projects: [],
       available_projects: [],
       commits: %{},
       jobs: %{},
       refs: %{},
       refs_t: %{},
       refs_i: %{}
     }}
  end

  def handle_info(:tick_jobs, state) do
    GenServer.cast(self(), {:query_jobs, %{}})
    Process.send_after(self(), :tick_jobs, current_poll_ms(state))
    {:noreply, state}
  end

  defp current_poll_ms(state) do
    secs =
      case state.inst do
        %{config: %{__struct__: @gitlab_config_module, poll_seconds: s}}
        when is_integer(s) and s > 0 ->
          s

        _ ->
          10
      end

    :timer.seconds(secs)
  end

  def pid(name) do
    "gitlab#{name}"
    |> via_tuple()
    |> GenServer.whereis()
  end

  # Public
  def refresh_db_cfg(name) do
    "gitlab#{name}"
    |> via_tuple()
    |> GenServer.cast(:refresh_db_cfg)
  end

  def query_projects(name) do
    "gitlab#{name}"
    |> via_tuple()
    |> GenServer.cast(:query_projects)
  end

  def query_commits(name) do
    "gitlab#{name}"
    |> via_tuple()
    |> GenServer.cast(:query_commits)
  end

  def query_jobs(name, query) do
    "gitlab#{name}"
    |> via_tuple()
    |> GenServer.cast({:query_jobs, query})
  end

  def read_projects(name, query) do
    "gitlab#{name}"
    |> via_tuple()
    |> GenServer.call({:read_projects, query})
  end

  def read_available_projects(name) do
    "gitlab#{name}"
    |> via_tuple()
    |> GenServer.call(:read_available_projects)
  end

  def read_commits(name, query) do
    "gitlab#{name}"
    |> via_tuple()
    |> GenServer.call({:read_commits, query})
  end

  def read_jobs(name, query) do
    "gitlab#{name}"
    |> via_tuple()
    |> GenServer.call({:read_jobs, query})
  end

  def handle_cast(:refresh_db_cfg, state) do
    inst = Configuration.get_source!(state.id)
    state = state |> Map.put(:inst, inst)
    filtered = filter_watched(state.available_projects, inst)
    watched_ids = filtered |> Enum.map(& &1["id"])

    commits = state.commits |> Map.take(watched_ids)
    jobs = state.jobs |> Map.take(watched_ids)

    {:noreply,
     state
     |> Map.put(:projects, filtered)
     |> Map.put(:commits, commits)
     |> Map.put(:jobs, jobs)}
  end

  defp filter_watched(projects, inst) when is_list(projects) do
    config = inst |> Map.get(:config) || %{}
    watched_projects = (Map.get(config, :projects) || []) |> Enum.map(&to_string/1)
    watched_namespaces = Map.get(config, :namespaces) || []

    case {watched_projects, watched_namespaces} do
      {[], []} ->
        projects

      _ ->
        Enum.filter(projects, fn p ->
          pid = p |> Map.get("id") |> to_string()
          ns = get_in(p, ["namespace", "full_path"]) || ""
          pid in watched_projects or ns in watched_namespaces
        end)
    end
  end

  defp filter_watched(_projects, _inst), do: []

  defp do_gitlab_req(uri, token, lookup, id \\ nil) do
    {path, params} =
      case lookup do
        # , %{updated_after: DateTime.utc_now |> DateTime.add(-3600 * 7) |> DateTime.truncate(:second) |> DateTime.to_iso8601, order_by: "updated_at"}}
        :projects -> {"/api/v4/projects", %{simple: true, per_page: 100}}
        :commits -> {"/api/v4/projects/#{id}/repository/commits/master", %{}}
        :jobs -> {"/api/v4/projects/#{id}/jobs", %{}}
      end

    case HTTPoison.get(
           uri <> path,
           ["PRIVATE-TOKEN": "#{token}", Accept: "Application/json; Charset=utf-8"],
           params: params,
           follow_redirect: true
         ) do
      {:ok, response} ->
        case response.status_code do
          500 ->
            Logger.info("Failed to retrieve data from Gitlab due to #{response.body}")
            {:error, :five_hundred}

          200 ->
            case response.body |> Poison.decode() do
              {:ok, decoded} -> {:ok, decoded}
              {:error, error} -> {:error, :decode_json}
            end

          404 ->
            {:error, :four_o_four}
        end

      {:error, error} ->
        Logger.info("Failed to retrieve data from Gitlab due to #{error.reason}")
        {:error, :http}
    end
  end

  defp do_gitlab_reqa(uri, token, lookup, id \\ nil) do
    {path, params} =
      case lookup do
        # , %{updated_after: DateTime.utc_now |> DateTime.add(-3600 * 7) |> DateTime.truncate(:second) |> DateTime.to_iso8601, order_by: "updated_at"}}
        :projects -> {"/api/v4/projects", %{simple: true, per_page: 100}}
        :commits -> {"/api/v4/projects/#{id}/repository/commits/master", %{}}
        :jobs -> {"/api/v4/projects/#{id}/jobs", %{}}
      end

    HTTPoison.get(
      uri <> path,
      ["PRIVATE-TOKEN": "#{token}", Accept: "Application/json; Charset=utf-8"],
      params: params,
      follow_redirect: true,
      stream_to: self()
    )
#    |> IO.inspect()
  end

  defp is_last_hour?(entry_field, hours \\ 1) do
    case entry_field |> DateTime.from_iso8601() do
      {:ok, dt, _something} ->
        DateTime.compare(dt, DateTime.utc_now() |> DateTime.add(-3600 * hours)) === :gt

      {:error, _error} ->
        false
    end
  end

  def handle_cast(:query_projects, state) do
    Logger.info("GLab::#{state.inst.id} Querying Projects")

    with true <- state |> Map.get(:inst, %{}) |> Map.get(:enabled),
         {url, pat} when is_binary(url) and is_binary(pat) <- gitlab_creds(state.inst) do
      {:ok, ref} = do_gitlab_reqa(url, pat, :projects)
      {:ok, fd} = StringIO.open("")
      refs = state |> Map.get(:refs)
      refs = refs |> Map.put(ref.id, %{fd: fd, type: :projects})

      {:noreply, state |> Map.put(:refs, refs)}
    else
      :no_creds ->
        Logger.warning("GLab::#{state.inst.id} skipping query_projects - config missing url/pat (type/config mismatch?)")
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  defp gitlab_creds(%{config: %{__struct__: @gitlab_config_module, url: url, pat: pat}})
       when is_binary(url) and is_binary(pat),
       do: {url, pat}

  defp gitlab_creds(_), do: :no_creds

  def handle_call({:read_projects, query}, _from, state) do
    {:reply, state[:projects], state}
  end

  def handle_call(:read_available_projects, _from, state) do
    {:reply, state[:available_projects], state}
  end

  def handle_cast(:query_commits, state) do
    with true <- state |> Map.get(:inst, %{}) |> Map.get(:enabled),
         {url, pat} when is_binary(url) and is_binary(pat) <- gitlab_creds(state.inst) do
      all =
        state.projects
        |> Enum.map(fn p ->
          Logger.info("GLab::#{state.inst.id} Querying Commits for #{p["name"]}")
          {:ok, ref} = do_gitlab_reqa(url, pat, :commits, p["id"])
          {:ok, fd} = StringIO.open("")
          {ref.id, %{fd: fd, type: :commits, id: p["id"]}}
        end)
        |> Map.new()

      refs = state |> Map.get(:refs) |> Map.merge(all)
      {:noreply, state |> Map.put(:refs, refs)}
    else
      _ -> {:noreply, state}
    end
  end

  def handle_call({:read_commits, query}, _from, state) do
    {:reply, state[:commits], state}
  end

  def handle_cast({:query_jobs, _query}, state) do
    with true <- state |> Map.get(:inst, %{}) |> Map.get(:enabled),
         {url, pat} when is_binary(url) and is_binary(pat) <- gitlab_creds(state.inst) do
      Logger.info("GLab::#{state.inst.id} Querying Jobs for #{length(state.projects)} watched projects")

      all =
        state.projects
        |> Enum.map(fn p ->
          id = p["id"]
          Logger.debug("GLab::#{state.inst.id} Querying Jobs for #{id}")
          {:ok, ref} = do_gitlab_reqa(url, pat, :jobs, id)
          {:ok, fd} = StringIO.open("")
          {ref.id, %{fd: fd, type: :jobs, id: id}}
        end)
        |> Map.new()

      refs = state |> Map.get(:refs) |> Map.merge(all)
      {:noreply, state |> Map.put(:refs, refs)}
    else
      _ ->
        {:noreply, state}
    end
  end

  def handle_call({:read_jobs, query}, _from, state) do
    project_ids = jobs_target_ids(query, state)
    statuses = parse_statuses(Map.get(query, :statuses) || Map.get(query, "statuses"))

    jobs =
      project_ids
      |> Enum.flat_map(fn id -> state[:jobs] |> Map.get(id) || [] end)
      |> filter_by_statuses(statuses)

    {:reply, jobs, state}
  end

  defp jobs_target_ids(query, state) do
    id = Map.get(query, :id) || Map.get(query, "id")
    ns = Map.get(query, :namespace) || Map.get(query, "namespace")

    cond do
      not is_nil(id) ->
        [id]

      is_binary(ns) and ns != "" ->
        state.available_projects
        |> Enum.filter(fn p -> get_in(p, ["namespace", "full_path"]) == ns end)
        |> Enum.map(& &1["id"])

      true ->
        Map.keys(state[:jobs] || %{})
    end
  end

  defp parse_statuses(nil), do: :all
  defp parse_statuses(s) when is_list(s), do: s
  defp parse_statuses(s) when is_binary(s) do
    case String.trim(s) do
      "" -> :all
      trimmed -> trimmed |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    end
  end

  defp filter_by_statuses(jobs, :all), do: jobs
  defp filter_by_statuses(jobs, [single]), do: Enum.filter(jobs, &(&1["status"] == single))
  defp filter_by_statuses(jobs, statuses) when is_list(statuses),
    do: Enum.filter(jobs, &Enum.member?(statuses, &1["status"]))

  def handle_call(_msg, _from, state) do
    {:reply, [:ok], state}
  end

  def handle_info(msg, state) do
    #    IO.inspect({:handle_info, msg})
    case msg do
      %HTTPoison.Error{reason: {:closed, :timeout}, id: resp_id} ->
        {:noreply, state}

      %HTTPoison.AsyncStatus{code: status_code, id: resp_id} ->
#        IO.inspect(status_code)

        if status_code == 200 do
          {:noreply, state}
        else
          refs = state[:refs]
          r = state[:refs][resp_id]
          r = r |> Map.put(:write, false)
          refs = refs |> Map.put(resp_id, r)
          {:noreply, state |> Map.put(:refs, refs)}
        end

      %HTTPoison.AsyncHeaders{headers: headers, id: resp_id} ->
#        IO.inspect(headers)
        {:noreply, state}

      %HTTPoison.AsyncChunk{chunk: chunk, id: resp_id} ->
        IO.binwrite(state[:refs][resp_id][:fd], chunk)
        {:noreply, state}

      %HTTPoison.AsyncEnd{id: resp_id} ->
        {_, str} = StringIO.contents(state[:refs][resp_id][:fd])
        StringIO.close(state[:refs][resp_id][:fd])
        t = state[:refs][resp_id][:type]

        case Poison.decode(str) do
          {:ok, decoded} ->
            case state[:refs][resp_id] |> Map.get(:write) do
              false ->
                {:noreply, state}

              nil ->
                case t do
                  :projects ->
                    filtered = filter_watched(decoded, state.inst)

                    {:noreply,
                     state
                     |> Map.put(:available_projects, decoded)
                     |> Map.put(:projects, filtered)}

                  x when x in [:commits, :jobs] ->
                    c = state |> Map.get(t)

                    i = state[:refs][resp_id][:id]
                    c = c |> Map.put(i, decoded)

                    {:noreply, state |> Map.put(t, c)}
                end
            end

          {:error, error} ->
            {:noreply, state}
        end
    end
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
