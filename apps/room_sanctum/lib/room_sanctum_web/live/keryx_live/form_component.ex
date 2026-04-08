defmodule RoomSanctumWeb.KeryxLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  def gen_name() do
    FriendlyID.generate(2, separator: "-")
  end

  defp inj_uid(params, socket) do
    params
    |> Map.put("user_id", socket.assigns.current_user.id)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage keryx records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="keryx-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" lb_a="generate-new-name" lb_i="fa-arrows-rotate" lb_tgt="#keryx-form" />

        <div class="form-control">
          <label class="block text-sm font-medium leading-6 text-primary-content mb-2">
            Queries
          </label>
          <input type="hidden" name="keryx[query_ids][]" value="" />
          <%= for query_id <- @selected_query_ids do %>
            <input type="hidden" name="keryx[query_ids][]" value={query_id} />
          <% end %>

          <%= for {tint, queries} <- @grouped_queries do %>
            <div class="mb-6">
              <%= if tint != "no-tint" do %>
                <div class="flex items-center gap-2 mb-3">
                  <i class={"fas fa-circle text-#{tint}-500"}></i>
                  <h4 class="text-md font-semibold text-primary-content capitalize"><%= tint %></h4>
                  <div class="flex-grow border-t border-base-300"></div>
                </div>
              <% else %>
                <div class="flex items-center gap-2 mb-3">
                  <i class="fas fa-circle text-base-content opacity-30"></i>
                  <h4 class="text-md font-semibold text-primary-content opacity-50">No Tint</h4>
                  <div class="flex-grow border-t border-base-300"></div>
                </div>
              <% end %>

              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                <%= for query <- queries do %>
                  <div
                    phx-click="toggle-query"
                    phx-value-query-id={query.id}
                    phx-target={@myself}
                    class={"card cursor-pointer transition-all hover:scale-105 relative #{if query.id in @selected_query_ids, do: "bg-primary text-primary-content border-2 border-primary-focus", else: "bg-base-200 hover:bg-base-300"}"}
                  >
                    <div class="card-body p-4">
                      <div class="flex items-center gap-2">
                        <%= if tint != "no-tint" do %>
                          <i class={"fas fa-circle text-#{tint}-500 text-xs"}></i>
                        <% end %>
                        <i class={"fas #{get_icon(query.source.type)} text-lg"}></i>
                        <span class="font-medium text-sm"><%= query.name %></span>
                      </div>
                      <div class="text-xs opacity-75 mt-1">
                        <%= query.source.name %>
                      </div>
                      <%= if query.id in @selected_query_ids do %>
                        <div class="absolute top-2 right-2">
                          <i class="fas fa-check-circle text-success"></i>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <.input field={@form[:ttl]} type="number" label="Ttl" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Keryx</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{keryx: keryx} = assigns, socket) do
    changeset = Configuration.change_keryx(keryx)
    queries = Configuration.list_cfg_queries({:user, assigns.current_user.id})
    grouped_queries = group_queries_by_tint(queries)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:available_queries, queries)
     |> assign(:grouped_queries, grouped_queries)
     |> assign(:selected_query_ids, keryx.query_ids || [])
     |> assign_new(:form, fn ->
       to_form(changeset)
     end)}
  end

  defp group_queries_by_tint(queries) do
    queries
    |> Enum.group_by(fn query ->
      cond do
        query.meta && query.meta.tint -> query.meta.tint
        query.source && query.source.meta && query.source.meta.tint -> query.source.meta.tint
        true -> "no-tint"
      end
    end)
    |> Enum.sort_by(fn {tint, _} -> if tint == "no-tint", do: "zzz", else: tint end)
  end

  defp get_query_tint(query) do
    cond do
      query.meta && query.meta.tint -> query.meta.tint
      query.source && query.source.meta && query.source.meta.tint -> query.source.meta.tint
      true -> nil
    end
  end

  @impl true
  def handle_event("validate", %{"keryx" => keryx_params}, socket) do
    keryx_params = inj_uid(keryx_params, socket)
    changeset = Configuration.change_keryx(socket.assigns.keryx, keryx_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"keryx" => keryx_params}, socket) do
    keryx_params = inj_uid(keryx_params, socket)
    save_keryx(socket, socket.assigns.action, keryx_params)
  end

  def handle_event("generate-new-name", _params, socket) do
    changeset = socket.assigns.changeset |> Ecto.Changeset.change(name: gen_name() |> String.downcase)
    {:noreply, assign(socket, changeset: changeset, form: to_form(changeset))}
  end

  def handle_event("toggle-query", %{"query-id" => query_id_str}, socket) do
    query_id = String.to_integer(query_id_str)
    selected = socket.assigns.selected_query_ids

    new_selected = if query_id in selected do
      List.delete(selected, query_id)
    else
      [query_id | selected]
    end

    changeset = socket.assigns.changeset |> Ecto.Changeset.change(query_ids: new_selected)

    {:noreply,
     socket
     |> assign(:selected_query_ids, new_selected)
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end

  def get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end

  defp save_keryx(socket, :edit, keryx_params) do
    case Configuration.update_keryx(socket.assigns.keryx, keryx_params) do
      {:ok, keryx} ->
        notify_parent({:saved, keryx})

        {:noreply,
         socket
         |> put_flash(:info, "Keryx updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset) |> IO.inspect)}
    end
  end

  defp save_keryx(socket, :new, keryx_params) do
    case Configuration.create_keryx(keryx_params) do
      {:ok, keryx} ->
        notify_parent({:saved, keryx})

        {:noreply,
         socket
         |> put_flash(:info, "Keryx created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset)  |> IO.inspect)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
