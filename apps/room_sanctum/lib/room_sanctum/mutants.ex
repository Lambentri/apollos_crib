defmodule RoomSanctum.Mutants do
  @moduledoc """
  Scribus resolutions, backed by the browser-ctl MutantDeployment.

  Each browser-ctl mutation runs snappers bound to the routing key in its
  `SNAP_RES`, and the scribe worker publishes to exactly that key -- so the
  mutations *are* the resolutions a Scribus can use. They are read from, and
  created and deleted through, the mutant operator's HTTP API rather than
  kept in a table that could drift from what is actually running.

  Mutations declared inline in the MutantDeployment (its manifest, in git)
  are listed but read-only: the operator refuses to delete them.
  """

  require Logger

  @env "SNAP_RES"

  defmodule Resolution do
    @moduledoc "One running (or starting) browser-ctl mutation."
    defstruct [:label, :resolution, :width, :height, :instances, :ready, :state, :source]

    @type t :: %__MODULE__{
            label: String.t(),
            resolution: String.t(),
            width: integer() | nil,
            height: integer() | nil,
            instances: integer(),
            ready: integer(),
            state: String.t(),
            source: :inline | :resource
          }

    def display(%__MODULE__{label: label, resolution: res}), do: "#{label} (#{res})"
  end

  @doc "Every resolution, in label order."
  @spec list_resolutions() :: {:ok, [Resolution.t()]} | {:error, String.t()}
  def list_resolutions do
    with {:ok, body} <- request(:get, "/mutations") do
      {:ok,
       body
       |> Enum.flat_map(&to_resolution/1)
       |> Enum.sort_by(& &1.label)}
    end
  end

  @doc """
  `{label, value}` options for a Scribus' resolution select: every Ready
  resolution, plus `current` if given and not among them, so editing a
  Scribus never silently drops the resolution it has.
  """
  @spec resolution_options(String.t() | nil) :: [{String.t(), String.t()}]
  def resolution_options(current \\ nil) do
    ready =
      case list_resolutions() do
        {:ok, list} -> Enum.filter(list, &(&1.state == "Ready"))
        {:error, _} -> []
      end

    options = Enum.map(ready, &{Resolution.display(&1), &1.resolution})

    if current in [nil, ""] or Enum.any?(options, fn {_, v} -> v == current end),
      do: options,
      else: options ++ [{"#{current} (not running)", current}]
  end

  @doc """
  Starts a resolution: a new mutation running `instances` snappers at
  `width`x`height`, labelled from `name`.
  """
  @spec create_resolution(String.t(), integer(), integer(), integer()) ::
          {:ok, String.t()} | {:error, String.t()}
  def create_resolution(name, width, height, instances \\ 1) do
    label = label_for(name)

    cond do
      label == "" ->
        {:error, "name needs at least one letter or digit"}

      not (is_integer(width) and width > 0 and is_integer(height) and height > 0) ->
        {:error, "width and height must be positive"}

      true ->
        body = %{label: label, env: %{@env => "#{width}x#{height}"}, instances: instances}

        with {:ok, _} <- request(:post, "/mutations", body), do: {:ok, label}
    end
  end

  @doc "Stops a resolution started through `create_resolution/4`."
  @spec delete_resolution(String.t()) :: :ok | {:error, String.t()}
  def delete_resolution(label) do
    with {:ok, _} <- request(:delete, "/mutations/" <> URI.encode_www_form(label)), do: :ok
  end

  @doc """
  The mutation label for a display name: lowercase alphanumerics and '-',
  as the operator requires (it becomes part of a Deployment name).

      iex> RoomSanctum.Mutants.label_for("InkPad 5 (landscape)")
      "inkpad-5-landscape"
  """
  def label_for(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 63)
    |> String.trim_trailing("-")
  end

  # A mutation without SNAP_RES is not a resolution a Scribus can target.
  defp to_resolution(%{"label" => label, "env" => %{@env => res}} = m) do
    {w, h} = parse(res)
    status = m["status"] || %{}

    [
      %Resolution{
        label: label,
        resolution: res,
        width: w,
        height: h,
        instances: m["instances"],
        ready: status["readyReplicas"] || 0,
        state: status["state"] || "Unknown",
        source: if(get_in(m, ["source", "kind"]) == "inline", do: :inline, else: :resource)
      }
    ]
  end

  defp to_resolution(_), do: []

  defp parse(res) do
    with [w, h] <- String.split(res, "x"),
         {w, ""} <- Integer.parse(w),
         {h, ""} <- Integer.parse(h) do
      {w, h}
    else
      _ -> {nil, nil}
    end
  end

  defp request(method, path, body \\ nil) do
    cfg = Application.get_env(:room_sanctum, __MODULE__, [])

    case cfg[:url] do
      url when url in [nil, ""] ->
        {:error, "mutant operator API is not configured (MUTANT_API_URL)"}

      url ->
        full =
          String.trim_trailing(url, "/") <>
            "/api/v1/namespaces/#{cfg[:namespace]}/mutantdeployments/#{cfg[:mutant_deployment]}" <>
            path

        headers =
          [{"accept", "application/json"}, {"content-type", "application/json"}] ++
            if(cfg[:token] in [nil, ""], do: [], else: [{"authorization", "Bearer #{cfg[:token]}"}])

        payload = if body, do: Jason.encode!(body), else: ""
        send_request(method, full, payload, headers)
    end
  end

  defp send_request(method, url, payload, headers) do
    case HTTPoison.request(method, url, payload, headers, recv_timeout: 5_000) do
      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code in 200..299 ->
        {:ok, if(body == "", do: nil, else: Jason.decode!(body))}

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, error_message(code, body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warning("mutant operator unreachable: #{inspect(reason)}")
        {:error, "mutant operator unreachable"}
    end
  rescue
    # hackney can throw rather than return for an unreachable host.
    e ->
      Logger.warning("mutant operator request failed: #{Exception.message(e)}")
      {:error, "mutant operator unreachable"}
  end

  defp error_message(code, body) do
    case Jason.decode(body) do
      {:ok, %{"error" => msg}} -> msg
      _ -> "mutant operator answered #{code}"
    end
  end
end
