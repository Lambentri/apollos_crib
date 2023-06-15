defmodule RoomSanctumWeb.PythiaeLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration
  alias RoomSanctum.Accounts

  def gen_name() do
    FriendlyID.generate(2, separator: "-")
  end

  defp inj_uid(params, socket) do
    params
    |> Map.put("user_id", socket.assigns.current_user.id)
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
    }
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
