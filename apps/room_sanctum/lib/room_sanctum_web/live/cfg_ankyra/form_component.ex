defmodule RoomSanctumWeb.AnkyraLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Accounts

  def convert_to_map(%model{} = schema) do
    Map.take(schema, model.__schema__(:fields))
  end

  def gen_pw() do
    # stolen from phx.gen
    token = :crypto.strong_rand_bytes(32)
    hashed_token = :crypto.hash(:sha256, token)
    Base.url_encode64(hashed_token, padding: false)
  end

  def gen_topic() do
    FriendlyID.generate(3, separator: "-")
  end


  defp inj_uid(params, socket) do
    params
    |> Map.put("user_id", socket.assigns.current_user.id)
  end

  @impl true
  def update(%{rabbit_user: rabbit_user} = assigns, socket) do
    changeset = case rabbit_user.id do
      nil ->  Accounts.change_rabbit_user(rabbit_user, %{"username" => Ecto.UUID.generate, "password" => gen_pw(), "topic" => gen_topic()})
      _val -> Accounts.change_rabbit_user(rabbit_user)
    end

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_form(changeset)
    }
  end

  @impl true
  def handle_event("validate", %{"ankyra" => ankyra_params}, socket) do
    ankyra_params = inj_uid(ankyra_params, socket)

    changeset =
      socket.assigns.rabbit_user
      |> Accounts.change_rabbit_user(ankyra_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"rabbit_user" => ankyra_params}, socket) do
    ankyra_params =
      inj_uid(ankyra_params, socket)
      |> Map.put(
        "place",
        socket.assigns
        |> Map.get(:place)
      )

    save_ankyra(socket, socket.assigns.action, ankyra_params)
  end

  def handle_event("save", %{}, socket) do
    params = socket.assigns.changeset |> Ecto.Changeset.change(user_id: socket.assigns.current_user.id)
    save_ankyra(socket, socket.assigns.action, params.changes)
  end

  def handle_event("generate-new-password", _params, socket) do
    changeset = socket.assigns.changeset |> Ecto.Changeset.change(password: gen_pw())
    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("generate-new-topic", _params, socket) do
    changeset = socket.assigns.changeset |> Ecto.Changeset.change(topic: gen_topic())
    {:noreply, assign_form(socket, changeset)}
  end


  defp save_ankyra(socket, :edit, ankyra_params) do
    case Accounts.update_rabbit_user(socket.assigns.rabbit_user, ankyra_params) do
      {:ok, ankyra} ->
        notify_parent({:saved, ankyra})

        {
          :noreply,
          socket
          |> put_flash(:info, "Ankyra updated successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_ankyra(socket, :new, ankyra_params) do
    case Accounts.create_rabbit_user(ankyra_params) do
      {:ok, ankyra} ->
        notify_parent({:saved, ankyra})

        {
          :noreply,
          socket
          |> put_flash(:info, "Ankyra created successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
