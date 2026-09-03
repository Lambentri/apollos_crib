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

        <label class="label label-text">Follow a tint</label>
        <div class="flex flex-wrap gap-2">
          <label class="cursor-pointer" title="Follow no tint">
            <input
              type="radio"
              name={@form[:follow_tint].name}
              value=""
              class="sr-only peer"
              checked={@form[:follow_tint].value in [nil, ""]}
            />
            <span class="inline-flex h-7 w-7 items-center justify-center rounded-full bg-base-300 ring-offset-2 ring-offset-base-100 peer-checked:ring-2 peer-checked:ring-accent">
              <i class="fa-solid fa-ban text-xs opacity-60"></i>
            </span>
          </label>

          <label :for={tint <- @tints} class="cursor-pointer" title={tint}>
            <input
              type="radio"
              name={@form[:follow_tint].name}
              value={tint}
              class="sr-only peer"
              checked={to_string(@form[:follow_tint].value) == tint}
            />
            <span class={"inline-flex h-7 w-7 rounded-full bg-#{tint}-500 ring-offset-2 ring-offset-base-100 peer-checked:ring-2 peer-checked:ring-accent"}>
            </span>
          </label>
        </div>
        <p class="text-xs text-base-content/60">
          Every source wearing this tint, without naming them. One tinted later
          joins on its own — that is what makes it worth following rather than
          selecting.
        </p>

        <label class="label label-text mt-2">And these in particular</label>
        <div class="flex flex-wrap gap-2">
          <label :for={source <- @cfg_sources} class="cursor-pointer">
            <input
              type="checkbox"
              name={"#{@form[:sources].name}[]"}
              value={source.id}
              class="sr-only peer"
              checked={source.id in (@form[:sources].value || [])}
            />
            <span class={[
              "inline-flex items-center gap-2 rounded-full border border-base-300 px-3 py-1 text-sm",
              "peer-checked:border-accent peer-checked:bg-accent/10",
              not spatial?(source.type) && "opacity-40"
            ]}>
              <.tint_dot tint={source.meta && source.meta.tint} />
              <i class={"fas fa-fw #{RoomSanctumWeb.IconHelpers.icon(source.type)}"}></i>
              <%= source.name %>
              <%= if not spatial?(source.type) do %>
                <i class="fas fa-fw fa-ban text-xs" title="Nothing located in this one"></i>
              <% end %>
            </span>
          </label>
        </div>
        <p class="text-xs text-base-content/60">
          Sources, not queries: a Plani asks what is near it rather than about a
          place named in advance. The faded ones have nothing located in them and
          are skipped — transit stops, loose bikes and air quality monitors are
          what can answer a question about where you are.
        </p>
        <%= if @form[:sources].value in [nil, []] and @form[:follow_tint].value in [nil, ""] do %>
          <p class="text-xs text-warning">
            <i class="fas fa-fw fa-triangle-exclamation"></i>
            Nothing selected, so this Plani will have nothing to say.
          </p>
        <% end %>

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
     |> assign(:cfg_ankyra_sel, Enum.map(ankyra, fn x -> {x.topic, x.id} end))
     |> assign(:cfg_sources, sources)
     |> assign(:tints, RoomSanctum.Tints.all())}
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

  # Which source types have anything with a location in them. The rest can be
  # picked, and are skipped when asked -- shown faded rather than hidden, so a
  # source that is missing from the answer is not also missing from the form.
  defp spatial?(type), do: type in [:gtfs, :gbfs, :aqi]

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
