defmodule RoomSanctumWeb.SearchComponent do
  import RoomSanctumWeb.CoreComponents
  use Phoenix.Component

  @impl true
  def render(assigns) do
    ~H"""
    qqq
    """
  end

  attr :type, :string, required: true
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :label_field, :string, required: true
  attr :value_field, :string, required: true

  def search_input(assigns) do
    ~H"""
    <.input field={@field} type="text" label={@label} phx-target={"##{@id}"} phx-keyup={"do-#{@type}-search"} phx-debounce="200" id={@id} />
    <ul class="menu bg-secondary">
    <%= for r <- @results |> Enum.slice(0..10) do %>
      <li class="hover-bordered">
        <a class="text-secondary-content" phx-click={"set-#{@type}"} phx-target={"##{@id}"} phx-value-val={r |> Map.from_struct |> Map.get @value_field} phx-value-type={@type}>
          <div class="flex justify-between w-full">
            <div><%= r |> Map.from_struct |> Map.get @label_field %></div>
            <div class="badge badge-accent"><%= r |> Map.from_struct |> Map.get @value_field %></div>
          </div>
      </a>
      </li>
    <% end %>
    </ul>
    """
  end

  def results(assigns) do
    ~H"""
    """
  end

  def result_item(assigns) do
    ~H"""
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
      socket
      |> assign(assigns)
      |> assign_new(:results, [])
      |> assign_new(:query, "")
    }
  end

  def handle_event("do-search",  params, socket) do
    IO.puts("search")
    {:noreply, socket}
  end
end
