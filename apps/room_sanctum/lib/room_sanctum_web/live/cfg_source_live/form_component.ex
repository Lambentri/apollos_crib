
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

  defp inj_uid(params, socket) do
    params = params |> Map.put("user_id", socket.assigns.current_user.id)

    params =
      case Map.has_key?(params, "config") do
        true -> params
        false -> params |> Map.put("config", %{})
      end
  end

  @impl true
  def update(%{source: source} = assigns, socket) do
    changeset = Configuration.change_source(source)
    run_period_idx = seconds_to_idx(source.meta && source.meta.run_period)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:tint_opts, ["red", "amber", "lime", "emerald", "sky", "violet", "fuchsia", "rose", "stone", "slate", "zinc"])
     |> assign(:run_period_idx, run_period_idx)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"source" => source_params}, socket) do
    source_params = source_params |> inj_uid(socket) |> convert_run_period_params()
    run_period_idx = get_in(source_params, ["meta", "run_period"])
      |> then(fn s -> if is_binary(s), do: String.to_integer(s), else: s end)
      |> seconds_to_idx()

    changeset =
      socket.assigns.source
      |> Configuration.change_source(source_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:run_period_idx, run_period_idx) |> assign_form(changeset)}
  end

  def handle_event("save", %{"source" => source_params}, socket) do
    source_params = source_params |> inj_uid(socket) |> convert_run_period_params()
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
