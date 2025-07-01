defmodule RoomSanctumWeb.VisionLive.FormComponent do
  use RoomSanctumWeb, :live_component
  import PolymorphicEmbed.HTML.Helpers

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Vision

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Configure your vision with custom queries</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="vision-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />

        <.input field={@form[:public]} type="checkbox" label="Make this vision public" />

        <div class="mt-6">
          <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Queries</h3>

          <div id="queries" class="space-y-4">
            <.inputs_for :let={query_form} field={@form[:queries]}>
              <div class="border rounded-lg p-4 relative">
                <input type="hidden" name="vision[queries_sort][]" value={query_form.index} />

                <div class="absolute top-2 right-2">
                  <.button
                    type="button"
                    phx-click="remove_query"
                    phx-value-index={query_form.index}
                    phx-target={@myself}
                    class="text-red-600 hover:text-red-800"
                  >
                    <.icon name="hero-trash" class="h-4 w-4" />
                  </.button>
                </div>

                <.input
                  field={query_form[:type]}
                  type="select"
                  label="Query Type"
                  options={[
                    {"Alerts", :alerts},
                    {"Time-based", :time},
                    {"Pinned", :pinned},
                    {"Background", :background}
                  ]}
                />

                <%= render_query_fields(query_form) %>
              </div>
            </.inputs_for>
          </div>

          <div class="mt-4">
            <.button type="button" phx-click="add_query" phx-target={@myself}>
              <.icon name="hero-plus" class="h-4 w-4 mr-1" /> Add Query
            </.button>
          </div>
        </div>

        <:actions>
          <.button phx-disable-with="Saving...">Save Vision</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{vision: vision} = assigns, socket) do
    changeset = Configuration.change_vision(vision)

    {:ok,
      socket
      |> assign(assigns)
      |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"vision" => vision_params}, socket) do
    changeset =
      socket.assigns.vision
      |> Configuration.change_vision(vision_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"vision" => vision_params}, socket) do
    save_vision(socket, socket.assigns.action, vision_params)
  end

  def handle_event("query_type_changed", %{"index" => index, "value" => new_type}, socket) do
    existing_queries = Map.get(socket.assigns.form.params, "queries", %{})

    updated_query =
      case Map.get(existing_queries, index) do
        nil -> %{"type" => new_type}
        query ->
          order = get_in(query, ["data", "order"]) || 1
          Map.put(query, "data", build_data_for_type(new_type, order))
      end

    updated_params =
      socket.assigns.form.params
      |> Map.put("queries", Map.put(existing_queries, index, updated_query))

    changeset =
      socket.assigns.vision
      |> Configuration.change_vision(updated_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp build_data_for_type(type, order) do
    base_data = %{"__type__" => type, "order" => order}

    case type do
      "time" ->
        Map.merge(base_data, %{
          "query" => nil,
          "weekdays" => [],
          "time_start" => nil,
          "time_end" => nil
        })

      "background" ->
        # Background query is optional, so we don't include it
        base_data

      _ ->
        # alerts and pinned require query
        Map.put(base_data, "query", nil)
    end
  end

  def handle_event("add_query", _params, socket) do
    existing_queries = Map.get(socket.assigns.form.params, "queries", %{})
    next_index = map_size(existing_queries)

    new_query = %{
      "type" => "pinned",
      "data" => %{
        "__type__" => "pinned",
        "order" => next_index + 1,
        "query" => nil
      }
    }

    updated_params =
      socket.assigns.form.params
      |> Map.put("queries", Map.put(existing_queries, to_string(next_index), new_query))

    changeset =
      socket.assigns.vision
      |> Configuration.change_vision(updated_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("remove_query", %{"index" => index}, socket) do
    existing_queries = Map.get(socket.assigns.form.params, "queries", %{})
    updated_queries = Map.delete(existing_queries, index)

    updated_params =
      socket.assigns.form.params
      |> Map.put("queries", updated_queries)
      |> Map.put("queries_drop", [index])

    changeset =
      socket.assigns.vision
      |> Configuration.change_vision(updated_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp save_vision(socket, :edit, vision_params) do
    case Configuration.update_vision(socket.assigns.vision, vision_params) do
      {:ok, vision} ->
        notify_parent({:saved, vision})

        {:noreply,
          socket
          |> put_flash(:info, "Vision updated successfully")
          |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_vision(socket, :new, vision_params) do
    vision_params = Map.put(vision_params, "user_id", socket.assigns.current_user.id)

    case Configuration.create_vision(vision_params) do
      {:ok, vision} ->
        notify_parent({:saved, vision})

        {:noreply,
          socket
          |> put_flash(:info, "Vision created successfully")
          |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp render_query_fields(query_form) do
    case Ecto.Changeset.get_field(query_form.source, :type) do
      :alerts -> render_alerts_fields(query_form)
      :time -> render_time_fields(query_form)
      :pinned -> render_pinned_fields(query_form)
      :background -> render_background_fields(query_form)
      _ -> render_empty_state()
    end
  end

  defp render_alerts_fields(query_form) do
    assigns = %{query_form: query_form}

    ~H"""
    <%= for data_form <- polymorphic_embed_inputs_for(@query_form, :data) do %>
      <%= hidden_inputs_for(data_form) %>
      <div class="grid grid-cols-2 gap-4 mt-4">
        <.input field={data_form[:query]} type="number" label="Query ID" />
        <.input field={data_form[:order]} type="number" label="Order" />
      </div>
    <% end %>
    """
  end

  defp render_time_fields(query_form) do
    assigns = %{query_form: query_form}

    ~H"""
    <%= for data_form <- polymorphic_embed_inputs_for(@query_form, :data) do %>
      <%= hidden_inputs_for(data_form) %>
      <div class="space-y-4 mt-4">
        <div class="grid grid-cols-2 gap-4">
          <.input field={data_form[:query]} type="number" label="Query ID" />
          <.input field={data_form[:order]} type="number" label="Order" />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Active Days</label>
          <div class="flex gap-2">
            <%= for {label, value} <- [{"Sun", :U}, {"Mon", :M}, {"Tue", :T}, {"Wed", :W}, {"Thu", :R}, {"Fri", :F}, {"Sat", :S}] do %>
              <label class="inline-flex items-center">
                <input
                  type="checkbox"
                  name={"vision[queries][#{@query_form.index}][data][weekdays][]"}
                  value={value}
                  checked={value in (Ecto.Changeset.get_field(data_form.source, :weekdays) || [])}
                  class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                />
                <span class="ml-1 text-sm"><%= label %></span>
              </label>
            <% end %>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={data_form[:time_start]} type="time" label="Start Time" />
          <.input field={data_form[:time_end]} type="time" label="End Time" />
        </div>
      </div>
    <% end %>
    """
  end

  defp render_pinned_fields(query_form) do
    assigns = %{query_form: query_form}

    ~H"""
    <%= for data_form <- polymorphic_embed_inputs_for(@query_form, :data) do %>
      <%= hidden_inputs_for(data_form) %>
      <div class="grid grid-cols-2 gap-4 mt-4">
        <.input field={data_form[:query]} type="number" label="Query ID" />
        <.input field={data_form[:order]} type="number" label="Order" />
      </div>
    <% end %>
    """
  end

  defp render_background_fields(query_form) do
    assigns = %{query_form: query_form}

    ~H"""
    <%= for data_form <- polymorphic_embed_inputs_for(@query_form, :data) do %>
      <%= hidden_inputs_for(data_form) %>
      <div class="grid grid-cols-2 gap-4 mt-4">
        <.input field={data_form[:query]} type="number" label="Query ID (optional)" />
        <.input field={data_form[:order]} type="number" label="Order" />
      </div>
    <% end %>
    """
  end

  defp render_empty_state do
    assigns = %{}

    ~H"""
    <div class="mt-4 text-sm text-gray-500">
      Select a query type to configure
    </div>
    """
  end
end