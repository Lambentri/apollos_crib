defmodule RoomGithub.Worker do
  @moduledoc false
  use GenServer

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus
  @github_config_module RoomSanctum.Configuration.Configs.Github
  @api_version "2022-11-28"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("github" <> opts[:name]))
  end

  def init(opts) do
    Periodic.start_link(
      every: :timer.seconds(10),
      run: fn -> RoomGithub.Worker.refresh_db_cfg(opts[:name]) end,
      initial_delay: 0
    )

    Periodic.start_link(
      every: :timer.seconds(60 * 60 * 6),
      run: fn -> RoomGithub.Worker.query_repos(opts[:name]) end,
      initial_delay: 2
    )

    # Runs/jobs cadence is configurable per source via config.poll_seconds; ticks self-reschedule.
    Process.send_after(self(), :tick_runs, :timer.seconds(8))
    Process.send_after(self(), :tick_jobs, :timer.seconds(14))

    {:ok,
     %{
       id: opts[:name],
       inst: %{},
       repos: [],
       available_repos: [],
       runs: %{},
       jobs: %{},
       refs: %{}
     }}
  end

  def pid(name) do
    "github#{name}"
    |> via_tuple()
    |> GenServer.whereis()
  end

  # Public API
  def refresh_db_cfg(name), do: cast(name, :refresh_db_cfg)
  def query_repos(name), do: cast(name, :query_repos)
  def query_runs(name), do: cast(name, :query_runs)
  def query_jobs(name), do: cast(name, :query_jobs)

  def read_available_repos(name), do: call(name, :read_available_repos)
  def read_runs(name, query), do: call(name, {:read_runs, query})
  def read_jobs(name, query), do: call(name, {:read_jobs, query})

  defp cast(name, msg), do: "github#{name}" |> via_tuple() |> GenServer.cast(msg)
  defp call(name, msg), do: "github#{name}" |> via_tuple() |> GenServer.call(msg)

  # Cast handlers
  def handle_cast(:refresh_db_cfg, state) do
    inst = Configuration.get_source!(state.id)
    state = state |> Map.put(:inst, inst)
    filtered = filter_watched(state.available_repos, inst)
    watched_full_names = filtered |> Enum.map(& &1["full_name"])

    runs = state.runs |> Map.take(watched_full_names)
    watched_run_ids = runs |> Map.values() |> List.flatten() |> Enum.map(& &1["id"])
    jobs = state.jobs |> Map.take(watched_run_ids)

    {:noreply,
     state
     |> Map.put(:repos, filtered)
     |> Map.put(:runs, runs)
     |> Map.put(:jobs, jobs)}
  end

  def handle_cast(:query_repos, state) do
    Logger.info("GH::#{state.inst.id} Querying Repos")

    with true <- state |> Map.get(:inst, %{}) |> Map.get(:enabled),
         {api_url, pat} when is_binary(api_url) and is_binary(pat) <- github_creds(state.inst) do
      owners = github_watched_owners(state.inst)

      paths =
        case owners do
          [] -> ["/user/repos"]
          list -> Enum.map(list, fn o -> "/orgs/#{o}/repos" end)
        end

      refs =
        Enum.reduce(paths, state.refs, fn path, acc ->
          case do_github_req(api_url, pat, path, %{"per_page" => 100, "type" => "all"}) do
            {:ok, ref} -> Map.put(acc, ref.id, %{type: :repos, fd: open_buffer(), page: 1})
            :error -> acc
          end
        end)

      {:noreply, state |> Map.put(:refs, refs)}
    else
      _ -> {:noreply, state}
    end
  end

  def handle_cast(:query_runs, state) do
    with true <- state |> Map.get(:inst, %{}) |> Map.get(:enabled),
         {api_url, pat} when is_binary(api_url) and is_binary(pat) <- github_creds(state.inst) do
      Logger.info("GH::#{state.inst.id} Querying Runs for #{length(state.repos)} repos")

      refs =
        Enum.reduce(state.repos, state.refs, fn r, acc ->
          full = r["full_name"]

          case do_github_req(api_url, pat, "/repos/#{full}/actions/runs", %{"per_page" => 20}) do
            {:ok, ref} ->
              Map.put(acc, ref.id, %{type: :runs, fd: open_buffer(), full_name: full})

            :error ->
              acc
          end
        end)

      {:noreply, state |> Map.put(:refs, refs)}
    else
      _ -> {:noreply, state}
    end
  end

  def handle_cast(:query_jobs, state) do
    with true <- state |> Map.get(:inst, %{}) |> Map.get(:enabled),
         {api_url, pat} when is_binary(api_url) and is_binary(pat) <- github_creds(state.inst) do
      active_runs =
        state.runs
        |> Map.values()
        |> List.flatten()
        |> Enum.filter(&run_warrants_jobs?/1)

      Logger.info("GH::#{state.inst.id} Querying Jobs for #{length(active_runs)} runs")

      refs =
        Enum.reduce(active_runs, state.refs, fn run, acc ->
          full = get_in(run, ["repository", "full_name"]) || full_name_from_runs_state(state, run["id"])
          path = "/repos/#{full}/actions/runs/#{run["id"]}/jobs"

          case do_github_req(api_url, pat, path, %{"per_page" => 50}) do
            {:ok, ref} ->
              Map.put(acc, ref.id, %{
                type: :jobs,
                fd: open_buffer(),
                run_id: run["id"],
                full_name: full
              })

            :error ->
              acc
          end
        end)

      {:noreply, state |> Map.put(:refs, refs)}
    else
      _ -> {:noreply, state}
    end
  end

  # Call handlers
  def handle_call(:read_available_repos, _from, state),
    do: {:reply, state.available_repos, state}

  def handle_call({:read_runs, query}, _from, state) do
    runs =
      target_repos(query, state)
      |> Enum.flat_map(fn full -> Map.get(state.runs, full, []) end)
      |> filter_runs_by_status(query)

    {:reply, runs, state}
  end

  def handle_call({:read_jobs, query}, _from, state) do
    target_runs =
      target_repos(query, state)
      |> Enum.flat_map(fn full -> Map.get(state.runs, full, []) end)
      |> Enum.map(& &1["id"])

    jobs =
      target_runs
      |> Enum.flat_map(fn rid -> Map.get(state.jobs, rid, []) end)
      |> filter_jobs_by_status(query)

    {:reply, jobs, state}
  end

  def handle_call(_msg, _from, state), do: {:reply, [:ok], state}

  # Self-scheduled poll ticks (interval read live from config each cycle)
  def handle_info(:tick_runs, state) do
    GenServer.cast(self(), :query_runs)
    Process.send_after(self(), :tick_runs, current_poll_ms(state))
    {:noreply, state}
  end

  def handle_info(:tick_jobs, state) do
    GenServer.cast(self(), :query_jobs)
    Process.send_after(self(), :tick_jobs, current_poll_ms(state))
    {:noreply, state}
  end

  defp current_poll_ms(state) do
    secs =
      case state.inst do
        %{config: %{__struct__: @github_config_module, poll_seconds: s}} when is_integer(s) and s > 0 -> s
        _ -> 60
      end

    :timer.seconds(secs)
  end

  # HTTPoison async stream handlers
  def handle_info(msg, state) do
    case msg do
      %HTTPoison.Error{reason: {:closed, :timeout}} ->
        {:noreply, state}

      %HTTPoison.AsyncStatus{code: 200, id: _id} ->
        {:noreply, state}

      %HTTPoison.AsyncStatus{code: code, id: rid} ->
        Logger.info("GH::#{state.inst.id} non-200: #{code}")

        ref = state.refs[rid]
        ref = ref && Map.put(ref, :write, false)
        refs = if ref, do: Map.put(state.refs, rid, ref), else: state.refs
        {:noreply, state |> Map.put(:refs, refs)}

      %HTTPoison.AsyncHeaders{headers: headers, id: rid} ->
        case state.refs[rid] do
          nil ->
            {:noreply, state}

          ref ->
            ref = Map.put(ref, :next_url, parse_next_link(headers))
            {:noreply, state |> Map.put(:refs, Map.put(state.refs, rid, ref))}
        end

      %HTTPoison.AsyncChunk{chunk: chunk, id: rid} ->
        case state.refs[rid] do
          nil -> :ok
          %{fd: fd} -> IO.binwrite(fd, chunk)
        end

        {:noreply, state}

      %HTTPoison.AsyncEnd{id: rid} ->
        case state.refs[rid] do
          nil ->
            {:noreply, state}

          %{write: false} = ref ->
            close_buffer(ref.fd)
            {:noreply, state |> Map.put(:refs, Map.delete(state.refs, rid))}

          ref ->
            {_, body} = StringIO.contents(ref.fd)
            close_buffer(ref.fd)

            new_state =
              state
              |> ingest_response(ref, body)
              |> follow_pagination(ref)

            {:noreply, new_state |> Map.put(:refs, Map.delete(new_state.refs, rid))}
        end

      _ ->
        {:noreply, state}
    end
  end

  # Helpers
  defp open_buffer do
    {:ok, fd} = StringIO.open("")
    fd
  end

  defp close_buffer(fd), do: StringIO.close(fd)

  @max_pages 20

  defp do_github_req(api_url, pat, path, params) do
    qs = URI.encode_query(params)
    url = api_url <> path <> if qs == "", do: "", else: "?" <> qs
    do_github_get(url, pat)
  end

  defp do_github_get(url, pat) do
    headers = [
      {"Authorization", "Bearer #{pat}"},
      {"Accept", "application/vnd.github+json"},
      {"X-GitHub-Api-Version", @api_version},
      {"User-Agent", "apollos-crib"}
    ]

    case HTTPoison.get(url, headers,
           follow_redirect: true,
           stream_to: self()
         ) do
      {:ok, ref} ->
        {:ok, ref}

      {:error, err} ->
        Logger.warning("GH request error: #{inspect(err.reason)}")
        :error
    end
  end

  defp parse_next_link(headers) when is_list(headers) do
    link =
      Enum.find_value(headers, fn {k, v} ->
        if String.downcase(to_string(k)) == "link", do: v, else: nil
      end)

    case link do
      nil ->
        nil

      val ->
        val
        |> String.split(",")
        |> Enum.find_value(fn part ->
          case Regex.run(~r/<([^>]+)>;\s*rel="next"/, String.trim(part)) do
            [_, url] -> url
            _ -> nil
          end
        end)
    end
  end

  defp parse_next_link(_), do: nil

  defp follow_pagination(state, %{next_url: url, type: :repos, page: page} = ref)
       when is_binary(url) and page < @max_pages do
    case github_creds(state.inst) do
      {_api_url, pat} when is_binary(pat) ->
        case do_github_get(url, pat) do
          {:ok, new_ref} ->
            ref_info = %{
              type: :repos,
              fd: open_buffer(),
              page: page + 1
            }

            Logger.debug("GH::#{state.inst.id} paginating repos page #{page + 1}")
            state |> Map.put(:refs, Map.put(state.refs, new_ref.id, ref_info))

          :error ->
            state
        end

      _ ->
        state
    end
  end

  defp follow_pagination(state, %{next_url: url, type: :repos, page: page})
       when is_binary(url) and page >= @max_pages do
    Logger.warning("GH::#{state.inst.id} hit @max_pages cap (#{@max_pages}); stopping repo pagination")
    state
  end

  defp follow_pagination(state, _), do: state

  defp ingest_response(state, %{type: :repos}, body) do
    case Poison.decode(body) do
      {:ok, list} when is_list(list) ->
        merged = merge_repo_list(state.available_repos, list)
        filtered = filter_watched(merged, state.inst)

        state
        |> Map.put(:available_repos, merged)
        |> Map.put(:repos, filtered)

      _ ->
        state
    end
  end

  defp ingest_response(state, %{type: :runs, full_name: full}, body) do
    case Poison.decode(body) do
      {:ok, %{"workflow_runs" => runs}} when is_list(runs) ->
        runs = Enum.map(runs, fn r -> Map.put_new_lazy(r, "repository", fn -> %{"full_name" => full} end) end)
        Map.update!(state, :runs, &Map.put(&1, full, runs))

      _ ->
        state
    end
  end

  defp ingest_response(state, %{type: :jobs, run_id: rid} = ref, body) do
    case Poison.decode(body) do
      {:ok, %{"jobs" => jobs}} when is_list(jobs) ->
        full = Map.get(ref, :full_name) || full_name_from_runs_state(state, rid)

        annotated =
          Enum.map(jobs, fn j ->
            j
            |> Map.put_new("repository", %{"full_name" => full})
            |> Map.put_new("run_id", rid)
          end)

        Map.update!(state, :jobs, &Map.put(&1, rid, annotated))

      _ ->
        state
    end
  end

  defp ingest_response(state, _, _), do: state

  defp merge_repo_list(existing, fresh) do
    by_full = Map.new(existing, &{&1["full_name"], &1})

    fresh
    |> Enum.reduce(by_full, fn r, acc -> Map.put(acc, r["full_name"], r) end)
    |> Map.values()
    |> Enum.sort_by(& &1["full_name"])
  end

  defp filter_watched(repos, inst) when is_list(repos) do
    config = inst |> Map.get(:config) || %{}
    watched_repos = (Map.get(config, :repos) || []) |> MapSet.new()
    watched_owners = (Map.get(config, :owners) || []) |> MapSet.new()

    case {MapSet.size(watched_repos), MapSet.size(watched_owners)} do
      {0, 0} ->
        repos

      _ ->
        Enum.filter(repos, fn r ->
          full = r["full_name"] || ""
          owner = get_in(r, ["owner", "login"]) || ""
          MapSet.member?(watched_repos, full) or MapSet.member?(watched_owners, owner)
        end)
    end
  end

  defp filter_watched(_, _), do: []

  defp github_watched_owners(inst) do
    config = inst |> Map.get(:config) || %{}
    Map.get(config, :owners) || []
  end

  defp github_creds(%{config: %{__struct__: @github_config_module, api_url: url, pat: pat}})
       when is_binary(url) and is_binary(pat),
       do: {url, pat}

  defp github_creds(_), do: :no_creds

  defp run_warrants_jobs?(run) do
    case run["status"] do
      "in_progress" -> true
      "queued" -> true
      "waiting" -> true
      "completed" -> recently?(run["updated_at"], 3600)
      _ -> false
    end
  end

  defp recently?(nil, _), do: false

  defp recently?(iso, secs) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> DateTime.diff(DateTime.utc_now(), dt) < secs
      _ -> false
    end
  end

  defp full_name_from_runs_state(state, run_id) do
    Enum.find_value(state.runs, fn {full, runs} ->
      if Enum.any?(runs, &(&1["id"] == run_id)), do: full
    end)
  end

  defp target_repos(query, state) do
    repo = Map.get(query, :repo) || Map.get(query, "repo")
    owner = Map.get(query, :owner) || Map.get(query, "owner")

    cond do
      is_binary(repo) and repo != "" ->
        [repo]

      is_binary(owner) and owner != "" ->
        state.repos
        |> Enum.filter(fn r -> get_in(r, ["owner", "login"]) == owner end)
        |> Enum.map(& &1["full_name"])

      true ->
        state.repos |> Enum.map(& &1["full_name"])
    end
  end

  defp filter_runs_by_status(runs, query) do
    runs
    |> filter_by_field(query, "status", :status)
    |> filter_by_field(query, "conclusion", :conclusion)
  end

  defp filter_jobs_by_status(jobs, query) do
    jobs
    |> filter_by_field(query, "status", :status)
    |> filter_by_field(query, "conclusion", :conclusion)
  end

  defp filter_by_field(items, query, json_key, atom_key) do
    raw = Map.get(query, atom_key) || Map.get(query, to_string(atom_key))

    case parse_csv(raw) do
      :all -> items
      list -> Enum.filter(items, &Enum.member?(list, &1[json_key]))
    end
  end

  defp parse_csv(nil), do: :all
  defp parse_csv(""), do: :all

  defp parse_csv(s) when is_binary(s) do
    case String.trim(s) do
      "" -> :all
      t -> t |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    end
  end

  defp parse_csv(s) when is_list(s), do: s

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end
