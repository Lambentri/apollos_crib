defmodule RoomSanctumWeb.PlaniLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>A vision whose anchor moves with a client</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="plani-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />

        <div class="divider">Where it is</div>

        <.input
          field={@form[:home_foci_id]}
          type="select"
          label="Home foci"
          options={@cfg_foci_sel}
        />
        <p class="text-xs text-base-content/60">
          Where it falls back to. A Plani answers from here until a client reports,
          and returns here when one stops — nothing about a position is written down,
          so this is what it knows when it knows nothing else.
        </p>

        <.input
          field={@form[:ankyra_id]}
          type="select"
          label="Ankyra to follow"
          options={[{"— none, stay at home —", nil}] ++ @cfg_ankyra_sel}
        />
        <.input field={@form[:client_id]} type="text" label="Client id" />
        <p class="text-xs text-base-content/60">
          Which client on that Ankyra to follow. An Ankyra can carry several — a
          phone and a panel on a wall — and only one of them travels. Leave blank
          to follow whichever reported most recently.
        </p>

        <div class="divider">What to look for</div>

        <.input
          field={@form[:sources]}
          type="select"
          multiple={true}
          label="Sources"
          options={@cfg_sources_sel}
        />
        <p class="text-xs text-base-content/60">
          Sources, not queries: a Plani asks what is near it rather than about a
          place named in advance. Only sources with something located in them can
          answer — transit stops, loose bikes, air quality monitors.
        </p>

        <.input field={@form[:radius]} type="number" label="Radius (metres, 50-3000)" />
        <.input field={@form[:limit]} type="number" label="How many of each (1-20)" />

        <:actions>
          <.button phx-disable-with="Saving...">Save Plani</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{plani: plani} = assigns, socket) do
    uid = assigns.current_user.id
    focis = Configuration.list_focis({:user, uid})
    sources = Configuration.list_cfg_sources({:user, uid})
    ankyra = RoomSanctum.Accounts.list_users_rabbit({:user, uid})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(Configuration.change_plani(plani))
     |> assign(:cfg_foci_sel, Enum.map(focis, fn x -> {x.name, x.id} end))
     |> assign(:cfg_sources_sel, Enum.map(sources, fn x -> {x.name, x.id} end))
     |> assign(:cfg_ankyra_sel, Enum.map(ankyra, fn x -> {x.topic, x.id} end))}
  end

  @impl true
  def handle_event("validate", %{"plani" => params}, socket) do
    changeset =
      socket.assigns.plani
      |> Configuration.change_plani(with_user(params, socket))
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"plani" => params}, socket) do
    save(socket, socket.assigns.action, with_user(params, socket))
  end

  defp save(socket, :edit, params) do
    case Configuration.update_plani(socket.assigns.plani, params) do
      {:ok, plani} ->
        notify_parent({:saved, plani})

        {:noreply,
         socket
         |> put_flash(:info, "Plani updated")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save(socket, :new, params) do
    case Configuration.create_plani(params) do
      {:ok, plani} ->
        notify_parent({:saved, plani})

        {:noreply,
         socket
         |> put_flash(:info, "Plani created")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # The form does not offer an owner, so it is put back on the way through
  # rather than trusted from the browser.
  defp with_user(params, socket), do: Map.put(params, "user_id", socket.assigns.current_user.id)

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
