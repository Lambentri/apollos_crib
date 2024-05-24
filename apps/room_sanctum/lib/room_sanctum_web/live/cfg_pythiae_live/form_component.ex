defmodule RoomSanctumWeb.PythiaeLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration
  alias RoomSanctum.Accounts
  alias RoomSanctum.Configuration.Pythiae.Const


  def gen_name() do
    FriendlyID.generate(2, separator: "-")
  end

  defp inj_uid(params, socket) do
    params
    |> Map.put("user_id", socket.assigns.current_user.id)
  end

  def line(assigns) do
    assigns =
      assign(
        assigns,
        :deleted,
        Phoenix.HTML.Form.input_value(assigns.f_line, :delete) == true
      )

    ~H"""
    <div class={if(@deleted, do: "opacity-50")}>
      <input
        type="hidden"
        name={Phoenix.HTML.Form.input_name(@f_line, :delete)}
        value={to_string(Phoenix.HTML.Form.input_value(@f_line, :delete))}
      />
      <div class="flex gap-4 items-end">
        <div class="grow">
          <.input class="mt-0" field={@f_line[:title]} readonly={@deleted} label="Title" />
        </div>
        <div class="grow">
          <.input
            class="mt-0"
            field={@f_line[:body]}
            readonly={@deleted}
            label="Body"
          />
        </div>
        <.button
          class="grow-0"
          type="button"
          phx-click="delete-line"
          phx-value-index={@f_line.index}
          phx-target={@myself}
          disabled={@deleted}
        >
          Delete
        </.button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("add-const", _, socket) do
    socket =
      update(socket, :form, fn %{source: changeset} ->
        existing = Ecto.Changeset.get_embed(changeset, :consts)
        changeset = Ecto.Changeset.put_embed(changeset, :consts, existing ++ [%{}])
        to_form(changeset)
      end)

    {:noreply, socket}
  end

  def handle_event("delete-line", %{"index" => index}, socket) do
    index = String.to_integer(index)

    socket =
      update(socket, :form, fn %{source: changeset} ->
        existing = Ecto.Changeset.get_embed(changeset, :consts)
        {to_delete, rest} = List.pop_at(existing, index)

        lines =
          if Ecto.Changeset.change(to_delete).data.id do
            List.replace_at(existing, index, Ecto.Changeset.change(to_delete, delete: true))
          else
            rest
          end

        changeset
        |> Ecto.Changeset.put_embed(:consts, lines)
        |> to_form()
      end)

    {:noreply, socket}
  end


  @impl true
  def update(%{pythiae: pythiae} = assigns, socket) do
    changeset = Configuration.change_pythiae(pythiae)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign_form(changeset)
     |> assign(:cfg_ankyra, list_cfg_ankyra(assigns.current_user.id))
     |> assign(:cfg_visions, list_cfg_visions(assigns.current_user.id))
     |> assign(
       :cfg_ankyra_sel,
       list_cfg_ankyra(assigns.current_user.id)
       |> Enum.map(fn x -> {x.topic, x.id} end)
       |> Enum.into(%{})
     )
     |> assign(
       :cfg_visions_sel,
       list_cfg_visions(assigns.current_user.id)
       |> Enum.map(fn x -> {x.name, x.id} end)
       |> Enum.into(%{})
     )
     |> assign(
       :cfg_foci_sel,
       list_cfg_foci(assigns.current_user.id)
       |> Enum.map(fn x -> {x.name, x.id} end)
       |> Enum.into(%{})
     )
    |> assign(:consts, [
       %Const{title: "Fun Fact", body: "A Coconut will reach approx 10 meters per second before crushing your skull"},
       %Const{title: "Fun Fact", body: "Poseidon will take blood, it's guaranteed."}
     ])}
  end

  @impl true
  def handle_event("validate", %{"pythiae" => pythiae_params}, socket) do
    pythiae_params = inj_uid(pythiae_params, socket)

    changeset =
      socket.assigns.pythiae
      |> Configuration.change_pythiae(pythiae_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"pythiae" => pythiae_params}, socket) do
    pythiae_params = inj_uid(pythiae_params, socket)

    save_pythiae(socket, socket.assigns.action, pythiae_params)
  end

  def handle_event("generate-new-name", _params, socket) do
    changeset = socket.assigns.changeset |> Ecto.Changeset.change(name: gen_name())
    {:noreply, assign_form(socket, changeset)}
  end

  defp save_pythiae(socket, :edit, pythiae_params) do
    IO.inspect(pythiae_params)

    case Configuration.update_pythiae(socket.assigns.pythiae, pythiae_params) do
      {:ok, pythiae} ->
        notify_parent({:saved, pythiae})

        {:noreply,
         socket
         |> put_flash(:info, "Pythiae updated successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_pythiae(socket, :new, pythiae_params) do
    case Configuration.create_pythiae(pythiae_params) do
      {:ok, pythiae} ->
        notify_parent({:saved, pythiae})

        {:noreply,
         socket
         |> put_flash(:info, "Pythiae created successfully")
         |> push_redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp list_cfg_ankyra(uid) do
    Accounts.list_users_rabbit({:user, uid})
  end

  defp list_cfg_visions(uid) do
    Configuration.list_visions({:user, uid})
  end

  defp list_cfg_foci(uid) do
    Configuration.list_focis({:user, uid})
  end
end
