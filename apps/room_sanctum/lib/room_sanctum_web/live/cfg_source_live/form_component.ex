
defmodule RoomSanctumWeb.SourceLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  @run_period_steps [
    {1,  86_400},
    {3,  259_200},
    {7,  604_800},
    {14, 1_209_600},
    {21, 1_814_400},
    {28, 2_419_200},
  ]

  def run_period_steps, do: @run_period_steps

  defp seconds_to_idx(nil), do: 2
  defp seconds_to_idx(secs) do
    @run_period_steps
    |> Enum.with_index()
    |> Enum.min_by(fn {{_, s}, _} -> abs(s - secs) end)
    |> elem(1)
  end

  defp idx_to_seconds(idx) when is_binary(idx), do: idx_to_seconds(String.to_integer(idx))
  defp idx_to_seconds(idx) do
    {_, secs} = Enum.at(@run_period_steps, idx, {7, 604_800})
    secs
  end

  defp convert_run_period_params(source_params) do
    case get_in(source_params, ["meta", "run_period"]) do
      nil -> source_params
      idx -> put_in(source_params, ["meta", "run_period"], idx_to_seconds(idx))
    end
  end

  # GitHub poll-interval slider: index → label/seconds
  @github_poll_steps [
    {"15s", 15},
    {"30s", 30},
    {"1m", 60},
    {"2m", 120},
    {"5m", 300},
    {"10m", 600},
    {"30m", 1_800},
    {"1h", 3_600}
  ]

  def github_poll_steps, do: @github_poll_steps

  defp github_secs_to_idx(nil), do: 2
  defp github_secs_to_idx(secs) when is_integer(secs) do
    @github_poll_steps
    |> Enum.with_index()
    |> Enum.min_by(fn {{_, s}, _} -> abs(s - secs) end)
    |> elem(1)
  end

  defp github_idx_to_secs(idx) when is_binary(idx), do: github_idx_to_secs(String.to_integer(idx))
  defp github_idx_to_secs(idx) do
    {_, secs} = Enum.at(@github_poll_steps, idx, {"1m", 60})
    secs
  end

  defp convert_github_poll_params(source_params) do
    case get_in(source_params, ["config", "poll_idx"]) do
      nil ->
        source_params

      idx ->
        secs = github_idx_to_secs(idx)

        source_params
        |> put_in(["config", "poll_seconds"], secs)
        |> update_in(["config"], &Map.delete(&1, "poll_idx"))
    end
  end

  # GitHub API call estimate based on watched repos/owners and poll interval.
  # Returns {watched_repo_count, calls_per_hour, source} where source is
  # :exact (we counted all watched repos including those under watched owners),
  # :partial (some owners contribute repos we don't have available), or
  # :unknown (no watched config and no available list, can't estimate).
  defp github_estimate(config, available_repos, poll_seconds)
       when is_integer(poll_seconds) and poll_seconds > 0 do
    repos = Map.get(config, :repos) || []
    owners = Map.get(config, :owners) || []

    repo_set = MapSet.new(repos)

    owner_repos =
      available_repos
      |> Enum.filter(fn r -> Enum.member?(owners, get_in(r, ["owner", "login"]) || "") end)
      |> Enum.map(& &1["full_name"])
      |> MapSet.new()

    watched = MapSet.union(repo_set, owner_repos) |> MapSet.size()

    {watched, source} =
      cond do
        watched > 0 ->
          {watched, if(owners == [], do: :exact, else: :partial)}

        owners != [] ->
          {0, :partial}

        repos == [] and owners == [] and available_repos != [] ->
          {length(available_repos), :exact}

        true ->
          {0, :unknown}
      end

    cycles_per_hour = div(3600, max(poll_seconds, 1))
    # 1 runs poll per repo per cycle + ~1 jobs poll per repo (one active run avg)
    calls_per_hour = watched * 2 * cycles_per_hour

    %{watched: watched, calls: calls_per_hour, source: source, cycles: cycles_per_hour}
  end

  defp github_estimate(_, _, _),
    do: %{watched: 0, calls: 0, source: :unknown, cycles: 0}

  def github_estimate_class(calls) when calls >= 4500, do: "text-error"
  def github_estimate_class(calls) when calls >= 2500, do: "text-warning"
  def github_estimate_class(_), do: "text-base-content/70"

  # GitLab poll-interval slider (jobs polling)
  @gitlab_poll_steps [
    {"5s", 5},
    {"10s", 10},
    {"30s", 30},
    {"1m", 60},
    {"2m", 120},
    {"5m", 300},
    {"10m", 600},
    {"30m", 1_800}
  ]

  def gitlab_poll_steps, do: @gitlab_poll_steps

  defp gitlab_secs_to_idx(nil), do: 1
  defp gitlab_secs_to_idx(secs) when is_integer(secs) do
    @gitlab_poll_steps
    |> Enum.with_index()
    |> Enum.min_by(fn {{_, s}, _} -> abs(s - secs) end)
    |> elem(1)
  end

  defp gitlab_idx_to_secs(idx) when is_binary(idx), do: gitlab_idx_to_secs(String.to_integer(idx))
  defp gitlab_idx_to_secs(idx) do
    {_, secs} = Enum.at(@gitlab_poll_steps, idx, {"10s", 10})
    secs
  end

  defp convert_gitlab_poll_params(source_params) do
    case get_in(source_params, ["config", "gitlab_poll_idx"]) do
      nil ->
        source_params

      idx ->
        secs = gitlab_idx_to_secs(idx)

        source_params
        |> put_in(["config", "poll_seconds"], secs)
        |> update_in(["config"], &Map.delete(&1, "gitlab_poll_idx"))
    end
  end

  defp gitlab_estimate(config, available_projects, poll_seconds)
       when is_integer(poll_seconds) and poll_seconds > 0 do
    projects = Map.get(config, :projects) || []
    namespaces = Map.get(config, :namespaces) || []

    project_set = MapSet.new(projects |> Enum.map(&to_string/1))

    namespace_projects =
      available_projects
      |> Enum.filter(fn p ->
        Enum.member?(namespaces, get_in(p, ["namespace", "full_path"]) || "")
      end)
      |> Enum.map(&(to_string(&1["id"])))
      |> MapSet.new()

    watched = MapSet.union(project_set, namespace_projects) |> MapSet.size()

    {watched, source} =
      cond do
        watched > 0 ->
          {watched, if(namespaces == [], do: :exact, else: :partial)}

        namespaces != [] ->
          {0, :partial}

        projects == [] and namespaces == [] and available_projects != [] ->
          {length(available_projects), :exact}

        true ->
          {0, :unknown}
      end

    cycles_per_hour = div(3600, max(poll_seconds, 1))
    # 1 jobs poll per project per cycle
    calls_per_hour = watched * cycles_per_hour

    %{watched: watched, calls: calls_per_hour, source: source, cycles: cycles_per_hour}
  end

  defp gitlab_estimate(_, _, _),
    do: %{watched: 0, calls: 0, source: :unknown, cycles: 0}

  def gitlab_estimate_class(calls) when calls >= 18_000, do: "text-error"
  def gitlab_estimate_class(calls) when calls >= 9_000, do: "text-warning"
  def gitlab_estimate_class(_), do: "text-base-content/70"

  defp inj_uid(params, socket) do
    params = params |> Map.put("user_id", socket.assigns.current_user.id)

    params =
      case Map.has_key?(params, "config") do
        true -> params
        false -> params |> Map.put("config", %{})
      end

    sync_config_type(params)
  end

  # The polymorphic_embed form helper sets the hidden __type__ from the existing
  # struct, not from the requested form variant. When the source type and existing
  # config struct disagree, submission silently drops the new fields. Force the
  # config's __type__ to match the source's type field so cast_polymorphic_embed
  # rebuilds the correct struct.
  defp sync_config_type(%{"type" => type, "config" => config} = params)
       when is_binary(type) and is_map(config) and type != "" do
    Map.put(params, "config", Map.put(config, "__type__", type))
  end

  defp sync_config_type(params), do: params

  @impl true
  def update(%{source: source} = assigns, socket) do
    changeset = Configuration.change_source(source)
    run_period_idx = seconds_to_idx(source.meta && source.meta.run_period)

    gh_secs =
      case source.config do
        %RoomSanctum.Configuration.Configs.Github{poll_seconds: secs}
        when is_integer(secs) ->
          secs

        _ ->
          60
      end

    gh_available = Map.get(assigns, :gh_available_repos, [])
    gh_estimate = github_estimate(source.config || %{}, gh_available, gh_secs)

    gl_secs =
      case source.config do
        %RoomSanctum.Configuration.Configs.Gitlab{poll_seconds: secs}
        when is_integer(secs) ->
          secs

        _ ->
          10
      end

    gl_available = Map.get(assigns, :gl_available_projects, [])
    gl_estimate = gitlab_estimate(source.config || %{}, gl_available, gl_secs)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:tint_opts, ["red", "amber", "lime", "emerald", "sky", "violet", "fuchsia", "rose", "stone", "slate", "zinc"])
     |> assign(:run_period_idx, run_period_idx)
     |> assign(:github_poll_idx, github_secs_to_idx(gh_secs))
     |> assign(:github_estimate, gh_estimate)
     |> assign(:gitlab_poll_idx, gitlab_secs_to_idx(gl_secs))
     |> assign(:gitlab_estimate, gl_estimate)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"source" => source_params}, socket) do
    source_params =
      source_params
      |> inj_uid(socket)
      |> convert_run_period_params()
      |> convert_github_poll_params()
      |> convert_gitlab_poll_params()

    run_period_idx = get_in(source_params, ["meta", "run_period"])
      |> then(fn s -> if is_binary(s), do: String.to_integer(s), else: s end)
      |> seconds_to_idx()

    poll_secs =
      case get_in(source_params, ["config", "poll_seconds"]) do
        s when is_integer(s) -> s
        s when is_binary(s) -> String.to_integer(s)
        _ -> nil
      end

    type = source_params["type"] || (socket.assigns.source.type && to_string(socket.assigns.source.type))

    changeset =
      socket.assigns.source
      |> Configuration.change_source(source_params)
      |> Map.put(:action, :validate)

    config_for_estimate = Ecto.Changeset.get_field(changeset, :config) || socket.assigns.source.config || %{}

    {gh_idx, gh_estimate} =
      if type == "github" do
        gh_secs = poll_secs || 60
        {github_secs_to_idx(gh_secs),
         github_estimate(config_for_estimate, socket.assigns[:gh_available_repos] || [], gh_secs)}
      else
        {socket.assigns[:github_poll_idx] || 2, socket.assigns[:github_estimate] || %{watched: 0, calls: 0, source: :unknown, cycles: 0}}
      end

    {gl_idx, gl_estimate} =
      if type == "gitlab" do
        gl_secs = poll_secs || 10
        {gitlab_secs_to_idx(gl_secs),
         gitlab_estimate(config_for_estimate, socket.assigns[:gl_available_projects] || [], gl_secs)}
      else
        {socket.assigns[:gitlab_poll_idx] || 1, socket.assigns[:gitlab_estimate] || %{watched: 0, calls: 0, source: :unknown, cycles: 0}}
      end

    {:noreply,
     socket
     |> assign(:run_period_idx, run_period_idx)
     |> assign(:github_poll_idx, gh_idx)
     |> assign(:github_estimate, gh_estimate)
     |> assign(:gitlab_poll_idx, gl_idx)
     |> assign(:gitlab_estimate, gl_estimate)
     |> assign_form(changeset)}
  end

  def handle_event("save", %{"source" => source_params}, socket) do
    source_params =
      source_params
      |> inj_uid(socket)
      |> convert_run_period_params()
      |> convert_github_poll_params()
      |> convert_gitlab_poll_params()

    save_source(socket, socket.assigns.action, source_params)
  end

  defp save_source(socket, :edit, source_params) do
    case Configuration.update_source(socket.assigns.source, source_params) do
      {:ok, source} ->
        notify_parent({:saved, source})

        {:noreply,
         socket
         |> put_flash(:info, "Source updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_source(socket, :new, source_params) do
    case Configuration.create_source(source_params) do
      {:ok, source} ->
        notify_parent({:saved, source})

        {:noreply,
         socket
         |> put_flash(:info, "Source created successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
