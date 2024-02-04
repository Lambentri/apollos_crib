defmodule RoomGitlab.Worker do
  @moduledoc false
  use GenServer
  use Nebulex.Caching

  require Logger

  alias RoomSanctum.Configuration

  @ttl :timer.minutes(5)

  @registry :zeus

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

    Periodic.start_link(
      every: :timer.seconds(10),
      run: fn -> RoomGitlab.Worker.query_jobs(opts[:name], %{}) end,
      initial_delay: 6
    )

    {:ok,
     %{
       id: opts[:name],
       inst: %{},
       projects: [],
       commits: %{},
       jobs: %{},
       refs: %{},
       refs_t: %{},
       refs_i: %{}
     }}
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
    {:noreply, state |> Map.put(:inst, inst)}
  end

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

    case state |> Map.get(:inst, %{}) |> Map.get(:enabled) do
      true ->
        {:ok, ref} = do_gitlab_reqa(state.inst.config.url, state.inst.config.pat, :projects)
        {:ok, fd} = StringIO.open("")
        refs = state |> Map.get(:refs)
        refs = refs |> Map.put(ref.id, %{fd: fd, type: :projects})

        {:noreply, state |> Map.put(:refs, refs)}

      x when x in [false, nil] ->
        {:noreply, state}
    end
  end

  def handle_call({:read_projects, query}, _from, state) do
    {:reply, state[:projects], state}
  end

  def handle_cast(:query_commits, state) do
    if state |> Map.get(:inst, %{}) |> Map.get(:enabled) do
      IO.inspect(state.projects)
      all =
        state.projects
        |> Enum.map(
          fn p ->
            Logger.info("GLab::#{state.inst.id} Querying Commits for #{p["name"]}")
            {:ok, ref} =
              do_gitlab_reqa(state.inst.config.url, state.inst.config.pat, :commits, p["id"])

            {:ok, fd} = StringIO.open("")
            {ref.id, %{fd: fd, type: :commits, id: p["id"]}}
          end
        )
        |> Map.new()

      refs = state |> Map.get(:refs)
      refs = refs |> Map.merge(all)

      {:noreply, state |> Map.put(:refs, refs)}
    else
      {:noreply, state}
    end
  end

  def handle_call({:read_commits, query}, _from, state) do
    {:reply, state[:commits], state}
  end

  def handle_cast({:query_jobs, query}, state) do
    case state |> Map.get(:inst, %{}) |> Map.get(:enabled) do
      x when x in [false, nil] ->
        Logger.info("Instance not populated")
        {:noreply, state}

      true ->
        Logger.info("GLab::#{state.inst.id} Querying Jobs")
        all =
          state.commits
          |> Enum.filter(fn {k, v} -> v end)
          |> Enum.map(fn {id, enabled} ->
            Logger.debug("GLab::#{state.inst.id} Querying Jobs for #{id}")
            {:ok, ref} = do_gitlab_reqa(state.inst.config.url, state.inst.config.pat, :jobs, id)

            {:ok, fd} = StringIO.open("")
            {ref.id, %{fd: fd, type: :jobs, id: id}}
          end)
          |> Map.new()

        refs = state |> Map.get(:refs)
        refs = refs |> Map.merge(all)

        {:noreply, state |> Map.put(:refs, refs)}
    end
  end

  def handle_call({:read_jobs, %{statuses: statuses, id: id}}, _from, state)
      when is_list(statuses) do
    {:reply,
     state[:jobs] |> Map.get(id) |> Enum.filter(fn e -> Enum.member?(statuses, e["status"]) end),
     state}
  end

  def handle_call({:read_jobs, %{statuses: statuses, id: id}}, _from, state)
      when is_binary(statuses) do
    {:reply, state[:jobs] |> Map.get(id) |> Enum.filter(fn e -> e["status"] == statuses end),
     state}
  end

  def handle_call({:read_jobs, %{statuses: statuses}}, _from, state) when is_list(statuses) do
    {:reply,
     state[:jobs]
     |> Enum.map(fn {k, j} ->
       j |> Enum.filter(fn e -> Enum.member?(statuses, e["status"]) end)
     end)
     |> List.flatten(), state}
  end

  def handle_call({:read_jobs, %{statuses: statuses}}, _from, state) when is_binary(statuses) do
    {:reply,
     state[:jobs]
     |> Enum.map(fn {k, j} -> j |> Enum.filter(fn e -> e["status"] == statuses end) end)
     |> List.flatten(), state}
  end

  def handle_call({:read_jobs, %{id: id}}, _from, state) do
    {:reply, state[:jobs] |> Map.get(id), state}
  end

  def handle_call({:read_jobs, %{}}, _from, state) do
    {:reply, state[:jobs], state}
  end

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
                    {:noreply, state |> Map.put(t, decoded)}

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
