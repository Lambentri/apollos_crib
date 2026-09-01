defmodule RoomSanctumWeb.VisionLive.FormComponent do
  use RoomSanctumWeb, :live_component
  import PolymorphicEmbed.HTML.Helpers

  alias RoomSanctum.Configuration
  alias RoomSanctum.Configuration.Vision

  alias RoomSanctum.Configuration.Vision.{Schema, Schema2Pinned}

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

        <.inputs_for :let={meta} field={@form[:meta]}>
          <div class="form-control mt-4">
            <label class="label label-text">Tint</label>
            <div class="flex flex-wrap gap-2">
              <%!-- The radio is sr-only; the swatch carries the whole state,
                    the same way bulk paint does. --%>
              <label class="cursor-pointer" title="No tint">
                <input
                  type="radio"
                  name={meta[:tint].name}
                  value=""
                  class="sr-only"
                  checked={meta[:tint].value in [nil, ""]}
                />
                <span class={"#{tint_swatch(meta[:tint].value in [nil, ""])} bg-base-300"}>
                  <i class="fa-solid fa-ban text-xs opacity-60"></i>
                </span>
              </label>

              <label :for={tint <- RoomSanctum.Tints.all()} class="cursor-pointer" title={tint}>
                <input
                  type="radio"
                  name={meta[:tint].name}
                  value={tint}
                  class="sr-only"
                  checked={to_string(meta[:tint].value) == tint}
                />
                <span class={"#{tint_swatch(to_string(meta[:tint].value) == tint)} bg-#{tint}-500"}>
                  <i :if={to_string(meta[:tint].value) == tint} class="fa-solid fa-check text-xs text-white"></i>
                </span>
              </label>
            </div>
          </div>
        </.inputs_for>

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
                    <.icon name="fa-trash" class="h-4 w-4" />
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

                <%= render_query_fields(query_form, assigns) %>
              </div>
            </.inputs_for>
          </div>

          <div class="mt-4">
            <.button type="button" phx-click="add_query" phx-target={@myself}>
              <.icon name="fa-plus" class="h-4 w-4 mr-1" /> Add Query
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
    # inputs_for renders nothing for a nil embed, so a vision that has never
    # been tinted would show no picker at all.
    changeset = vision |> with_meta() |> Configuration.change_vision()

    {:ok,
      socket
      |> assign(assigns)
      |> assign_new(:query_search, fn -> %{} end)
      |> assign(:available_queries, available_queries(assigns))
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

  # Both of these edit the list of queries the form is currently showing, which
  # lives on the changeset -- not in `form.params`.
  #
  # form.params holds what has been *submitted*, and on a form the user has
  # only just opened that is `%{}`. Building `"queries" => %{...}` params from
  # it therefore told cast_embed the form had no queries at all, and with
  # `on_replace: :delete` on the embed that is an instruction to drop every
  # one: removing a single query emptied the list, and adding one replaced the
  # list with it. The queries came back on reload, since none of this was
  # saved, which is what made it look like a rendering fault rather than a
  # destroyed changeset.
  #
  # A third handler, "query_type_changed", had the same defect and no way to
  # fire -- nothing in the markup dispatched it, and the type select goes
  # through "validate" with the whole form like any other input -- so it is
  # gone rather than fixed.
  def handle_event("add_query", _params, socket) do
    update_queries(socket, fn queries ->
      queries ++ [%Schema{type: :pinned, data: %Schema2Pinned{order: length(queries) + 1}}]
    end)
  end

  def handle_event("remove_query", %{"index" => index}, socket) do
    index = String.to_integer(index)

    update_queries(socket, fn queries -> List.delete_at(queries, index) end)
  end

  # What has been typed into one row's query box. Per row, because two rows are
  # searching for different things.
  def handle_event("query_search", %{"index" => index, "value" => value}, socket) do
    {:noreply, assign(socket, :query_search, Map.put(socket.assigns.query_search, index, value))}
  end

  def handle_event("query_pick", %{"index" => index, "id" => id}, socket) do
    row = String.to_integer(index)
    id = String.to_integer(id)

    socket
    # The box goes back to showing the chosen query's name rather than what was
    # typed to find it.
    |> assign(:query_search, Map.delete(socket.assigns.query_search, index))
    |> update_queries(fn queries -> List.update_at(queries, row, &choose_query(&1, id)) end)
  end

  # A changeset for the row, not a struct with the id written into it.
  #
  # put_embed pairs what it is given against what is already there and keeps
  # the existing record where the two are the same row -- so a copy of the
  # struct with a different query id in it registers as no change at all, and
  # the pick was lost somewhere between the click and the save. Saying it as a
  # changeset says explicitly what changed. (Removal was never affected: a
  # shorter list is a difference put_embed does see.)
  defp choose_query(query, id) do
    data =
      (query.data || %{})
      |> Map.from_struct()
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.put("__type__", to_string(query.type))
      |> Map.put("query", id)

    Schema.changeset(query, %{"type" => to_string(query.type), "data" => data})
  end

  # A query belongs on a vision once, so the ones other rows are already
  # pointing at are not offered here. This row's own choice stays in the list --
  # take it out and the box has nothing to show for what it is set to.
  defp selectable_queries(assigns, index) do
    taken =
      assigns.form.source
      |> Ecto.Changeset.get_field(:queries)
      |> List.wrap()
      |> Enum.with_index()
      |> Enum.reject(fn {_query, row} -> row == index end)
      |> Enum.map(fn {query, _row} -> query.data && Map.get(query.data, :query) end)
      |> MapSet.new()

    Enum.reject(assigns.available_queries, &MapSet.member?(taken, &1.id))
  end

  # A vision can only point at its owner's queries. On the "new" form there is
  # no vision yet, so the user comes from the assigns the parent passes.
  defp available_queries(%{current_user: %{id: user_id}}) do
    {:user, user_id}
    |> Configuration.list_cfg_queries()
    |> Enum.sort_by(& &1.name)
  end

  defp available_queries(_assigns), do: []

  # The changeset the form is rendering from, with its queries put back through
  # `fun`. Starting from that changeset rather than from the vision keeps any
  # unsaved edits to the fields around it -- a renamed vision does not revert
  # because a query was removed.
  defp update_queries(socket, fun) do
    changeset = socket.assigns.form.source

    changeset =
      changeset
      |> Ecto.Changeset.put_embed(:queries, fun.(Ecto.Changeset.get_field(changeset, :queries)))
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

  defp with_meta(%{meta: nil} = vision),
    do: %{vision | meta: %RoomSanctum.Configuration.Vision.Meta{}}

  defp with_meta(vision), do: vision

  defp tint_swatch(selected?) do
    base = "flex items-center justify-center w-7 h-7 rounded-full"

    if selected?,
      do: base <> " ring-2 ring-offset-2 ring-offset-base-100 ring-base-content",
      else: base <> " opacity-70 hover:opacity-100"
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp render_query_fields(query_form, assigns) do
    picker = %{
      index: query_form.index,
      queries: selectable_queries(assigns, query_form.index),
      search: Map.get(assigns.query_search, to_string(query_form.index)),
      target: assigns.myself
    }

    case Ecto.Changeset.get_field(query_form.source, :type) do
      :alerts -> render_alerts_fields(query_form, picker)
      :time -> render_time_fields(query_form, picker)
      :pinned -> render_pinned_fields(query_form, picker)
      :background -> render_background_fields(query_form, picker)
      _ -> render_empty_state()
    end
  end

  @doc """
  Pick a query by name.

  The field holds a query id, which is the wrong thing to ask a person to
  remember -- so the box shows the name of whatever is chosen, the id rides
  along in a hidden input, and typing filters the queries this user owns.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :index, :integer, required: true
  attr :queries, :list, required: true
  attr :search, :string, default: nil
  attr :target, :any, required: true
  attr :label, :string, default: "Query"

  def query_picker(assigns) do
    selected = Enum.find(assigns.queries, &(to_string(&1.id) == to_string(assigns.field.value)))

    assigns =
      assigns
      |> assign(:selected, selected)
      # Nil search means nothing has been typed here: show what is chosen. An
      # empty string means the box was cleared, which is a search for
      # everything rather than a fresh start.
      |> assign(:text, assigns.search || (selected && selected.name) || "")
      |> assign(:matches, matching_queries(assigns.queries, assigns.search))

    ~H"""
    <div class="form-control relative">
      <label class="label"><span class="label-text"><%= @label %></span></label>
      <input type="hidden" name={@field.name} value={@field.value} />
      <input
        type="text"
        class="input input-bordered w-full"
        value={@text}
        placeholder="Search your queries"
        autocomplete="off"
        phx-keyup="query_search"
        phx-value-index={@index}
        phx-target={@target}
        phx-debounce="150"
      />
      <%!-- Above the fields under it, and scrolling rather than growing the
            modal when a search matches everything. --%>
      <ul
        :if={@matches != []}
        class="menu menu-compact bg-base-200 rounded-box absolute top-full left-0 z-20 w-full max-h-56 overflow-y-auto shadow-lg"
      >
        <li :for={q <- @matches}>
          <a phx-click="query_pick" phx-value-index={@index} phx-value-id={q.id} phx-target={@target}>
            <i class={"fa-solid fa-fw #{get_icon(q.source.type)}"}></i>
            <span class="grow truncate"><%= q.name %></span>
            <span class="badge badge-sm badge-ghost"><%= q.source.name %></span>
          </a>
        </li>
      </ul>
      <p :if={@search not in [nil, ""] and @matches == []} class="text-xs opacity-60 mt-1">
        No queries match "<%= @search %>"
      </p>
    </div>
    """
  end

  # Nothing typed yet means the list stays shut: the box is already showing the
  # answer, and a dropdown over the fields below it would be in the way.
  defp matching_queries(_queries, nil), do: []

  defp matching_queries(queries, search) do
    search = String.downcase(search)

    queries
    |> Enum.filter(fn q ->
      String.contains?(String.downcase(q.name), search) or
        String.contains?(String.downcase(q.source.name), search)
    end)
    |> Enum.take(25)
  end

  defp get_icon(type), do: RoomSanctumWeb.IconHelpers.icon(type)

  defp render_alerts_fields(query_form, picker) do
    assigns = %{query_form: query_form, picker: picker}

    ~H"""
    <%= for data_form <- polymorphic_embed_inputs_for(@query_form, :data) do %>
      <%= hidden_inputs_for(data_form) %>
      <div class="grid grid-cols-2 gap-4 mt-4">
        <.query_picker field={data_form[:query]} {@picker} />
        <.input field={data_form[:order]} type="number" label="Order" />
      </div>
    <% end %>
    """
  end

  defp render_time_fields(query_form, picker) do
    assigns = %{query_form: query_form, picker: picker}

    ~H"""
    <%= for data_form <- polymorphic_embed_inputs_for(@query_form, :data) do %>
      <%= hidden_inputs_for(data_form) %>
      <div class="space-y-4 mt-4">
        <div class="grid grid-cols-2 gap-4">
          <.query_picker field={data_form[:query]} {@picker} />
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

  defp render_pinned_fields(query_form, picker) do
    assigns = %{query_form: query_form, picker: picker}

    ~H"""
    <%= for data_form <- polymorphic_embed_inputs_for(@query_form, :data) do %>
      <%= hidden_inputs_for(data_form) %>
      <div class="grid grid-cols-2 gap-4 mt-4">
        <.query_picker field={data_form[:query]} {@picker} />
        <.input field={data_form[:order]} type="number" label="Order" />
      </div>
    <% end %>
    """
  end

  defp render_background_fields(query_form, picker) do
    assigns = %{query_form: query_form, picker: picker}

    ~H"""
    <%= for data_form <- polymorphic_embed_inputs_for(@query_form, :data) do %>
      <%= hidden_inputs_for(data_form) %>
      <div class="grid grid-cols-2 gap-4 mt-4">
        <.query_picker field={data_form[:query]} label="Query (optional)" {@picker} />
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