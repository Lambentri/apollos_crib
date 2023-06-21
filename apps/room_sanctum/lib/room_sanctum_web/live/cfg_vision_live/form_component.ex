defmodule RoomSanctumWeb.VisionLive.FormComponent do
  use RoomSanctumWeb, :live_component

  alias RoomSanctum.Configuration

  defp inj_uid(params, socket) do
    params
    #    |> IO.inspect
    |> Map.put("user_id", socket.assigns.current_user.id)
    |> Map.put(
      "query_ids",
      params |> Map.get("queries", %{}) |> Enum.map(fn {k, v} -> v["data"]["query"] end)
    )
  end

  defp inj_types(params) do
    params
    |> Map.put(
      "queries",
      params
      |> Map.get("queries", %{})
      |> Enum.map(fn {k, v} -> {k, v |> Kernel.put_in(["data", "__type__"], v["type"])} end)
      |> Enum.into(%{})
    )
  end

  @impl true
  def update(%{vision: vision} = assigns, socket) do
    changeset = Configuration.change_vision(vision)

    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_form(changeset)
      |> assign(:cfg_queries, list_cfg_queries(assigns.current_user.id))
      |> assign(
        :cfg_queries_sel,
        list_cfg_queries(assigns.current_user.id)
        |> Enum.map(fn x -> {"#{x.name} (#{x.source.type})", x.id} end)
        |> Enum.into(%{})
      )
    }
  end

  @impl true
  def handle_event("validate", %{"vision" => vision_params}, socket) do
    IO.puts("cvl-valid")
    vision_params = inj_uid(vision_params, socket)

    changeset =
      socket.assigns.vision
      |> Configuration.change_vision(vision_params)
      |> Map.put(:action, :validate)

    #      |> IO.inspect()

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"vision" => vision_params}, socket) do
    IO.puts("cvl-save")
    vision_params = inj_uid(vision_params, socket) |> inj_types
    save_vision(socket, socket.assigns.action, vision_params)
  end

  def handle_event("add-entry", _data, socket) do
    #    IO.inspect(socket.assigns.form)
    f = socket.assigns.form

    existing_as_simple =
      case f.params do
        map when map == %{} ->
          f.data.queries
          |> Poison.encode!()
          |> Poison.decode!()
          |> Enum.with_index()
          |> Enum.map(fn {k, v} -> {"#{v}", k} end)
          |> Map.new()

        # |> Enum.map(fn {k,v} -> v end)
        otherwise ->
          f.params |> Map.get("queries")
      end

    #     IO.inspect(existing_as_simple)
    combined =
      case existing_as_simple do
        list when list == [] ->
          %{
            "0" => %{
              "data" => %{"__type__" => "pinned", "query" => 0},
              "id" => nil,
              "type" => "pinned",
              "order" => 0
            }
          }

        _otherwise ->
          existing_as_simple
          |> Map.merge(%{
            "#{existing_as_simple |> Map.keys() |> length}" => %{
              "data" => %{"__type__" => "pinned", "query" => 0},
              "id" => nil,
              "type" => "pinned",
              "order" => 0
            }
          })
      end

    changeset =
      socket.assigns.vision
      |> Configuration.change_vision(%{queries: combined})
      |> Map.put(:action, :validate)

    #      |> IO.inspect()

    {
      :noreply,
      socket
      |> assign_form(changeset)
    }
  end

  defp save_vision(socket, :edit, vision_params) do
    case Configuration.update_vision(socket.assigns.vision, vision_params) do
      {:ok, vision} ->
        notify_parent({:saved, vision})

        {
          :noreply,
          socket
          |> put_flash(:info, "Vision updated successfully")
          |> push_redirect(to: socket.assigns.patch)
        }

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_vision(socket, :new, vision_params) do
    case Configuration.create_vision(vision_params) do
      {:ok, vision} ->
        notify_parent({:saved, vision})

        {
          :noreply,
          socket
          |> put_flash(:info, "Vision created successfully")
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

  defp list_cfg_queries(uid) do
    Configuration.list_cfg_queries({:user, uid})
  end

  defp etuple(:U) do
    {"Sunday", "U"}
  end

  defp etuple(:M) do
    {"Monday", "M"}
  end

  defp etuple(:T) do
    {"Tuesday", "T"}
  end

  defp etuple(:W) do
    {"Wednesday", "W"}
  end

  defp etuple(:R) do
    {"Thursday", "R"}
  end

  defp etuple(:F) do
    {"Friday", "F"}
  end

  defp etuple(:S) do
    {"Saturday", "S"}
  end

  defp gfv(form, fq, ctr) do
    #    IO.puts("GFV")
    #    IO.inspect(changeset)
    #    IO.inspect(fq)
    #
    #    IO.inspect(
    #      fq.data
    #      |> Map.get(:type)
    #    )
    #    IO.inspect(
    #      fq.source.data
    #      |> Map.get(:type)
    #    )

    q =
      form.params |> Map.get("queries", %{}) |> Map.get("#{ctr}", %{}) |> Map.get("type") ||
        form.data
        |> Map.get(:queries, [])
        |> Enum.at(ctr, %{})
        |> Map.get(:changes, %{})
        |> Map.get(:type) ||
        fq.data
        |> Map.get(:source, %{})
        |> Map.get(:changes, %{})
        |> Map.get(:type) ||
        fq.source
        |> Map.get(:data, %{})
        |> Map.get(:type)

    # |> IO.inspect
    q
  end
end
