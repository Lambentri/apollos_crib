defmodule RoomSanctumWeb.LiveHelpers do
  import Phoenix.LiveView
  import Phoenix.LiveView.Helpers

  alias Phoenix.LiveView.JS

  @doc """
  Renders a live component inside a modal.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <.modal return_to={Routes.source_index_path(@socket, :index)}>
        <.live_component
          module={RoomSanctumWeb.SourceLive.FormComponent}
          id={@source.id || :new}
          title={@page_title}
          action={@live_action}
          return_to={Routes.source_index_path(@socket, :index)}
          source: @source
        />
      </.modal>
  """
  def modal(assigns) do
    assigns = assign_new(assigns, :return_to, fn -> nil end)

    ~H"""
    <div id="modal" class="modal modal-bottom md:modal-middle z-50 fade-in" phx-remove={hide_modal()}>
      <div
        id="modal-content"
        class="fade-in-scale bg-primary modal-open max-w-5xl p-6 rounded-md"
        phx-click-away={JS.dispatch("click", to: "#close")}
        phx-window-keydown={JS.dispatch("click", to: "#close")}
        phx-key="escape">
        <%= if @return_to do %>
          <%= live_patch "✖",
            to: @return_to,
            id: "close",
            class: "phx-modal-close",
            phx_click: hide_modal()
          %>
        <% else %>
          <a id="close" href="#" class="phx-modal-close" phx-click={hide_modal()}>✖</a>
          <i id="fas fa-xmark"></i>
        <% end %>

        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp hide_modal(js \\ %JS{}) do
    js
    |> JS.hide(to: "#modal", transition: "fade-out")
    |> JS.hide(to: "#modal-content", transition: "fade-out-scale")
  end

  #
  def itb(assigns) do # icon-text-button
    assigns = assigns
              |> assign_new(:icon, fn -> "fa-poo-storm" end)
              |> assign_new(:what, fn -> "Poop" end)

    ~H"""
    <%= live_patch to: @to, class: "btn gap-2 float-right" do %>
      <i class={"fa-solid #{@icon}"}></i>

      <%= adj(@what) %> <%= @what %>
    <% end %>
    """
  end

  def ib(assigns) do
    assigns = assigns
              |> assign_new(:icon, fn -> "fa-poo-storm" end)
              |> assign_new(:function, fn -> :live_patch end)

    ~H"""
    <%= case @function do %>
      <%= :live_patch -> %>
      <%= live_patch to: @to, class: "btn btn-square btn-xs" do %>
        <i class={"fa-solid #{@icon}"}></i>
      <% end %>
      <% :live_redirect -> %>
      <%= live_redirect to: @to, class: "btn btn-square btn-xs" do %>
        <i class={"fa-solid #{@icon}"}></i>
      <% end %>
    <% end %>
    """
  end

  defp adj(what) do
    case what do
      "Edit" -> ""
      "Back" -> "Go"
      _ -> "New"
    end
  end
end
