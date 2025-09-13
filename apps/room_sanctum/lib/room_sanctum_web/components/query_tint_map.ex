defmodule RoomSanctumWeb.Components.QueryTintMap do
  use Phoenix.Component
  import RoomSanctumWeb.CoreComponents

  @doc """
  Renders a map visualization of queries organized by tint.
  
  ## Examples
  
      <.query_tint_map queries={@queries} available_tints={@available_tints} />
      
      <.query_tint_map queries={@queries} available_tints={@available_tints} 
                       selected_tint={@tint} on_tint_select={JS.push("set-tint")} />
  """
  attr :queries, :list, required: true
  attr :available_tints, :list, required: true 
  attr :selected_tint, :string, default: nil
  attr :on_tint_select, :any, default: nil
  attr :class, :string, default: ""

  def query_tint_map(assigns) do
    ~H"""
    <div class={"query-tint-map #{@class}"}>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 p-4">
        <%= for tint <- @available_tints do %>
          <div class={"tint-group border-2 border-#{tint}-300 rounded-lg p-4 #{if @selected_tint == tint, do: "ring-2 ring-#{tint}-500"}"}>
            <div class="flex items-center justify-between mb-3">
              <h3 class={"text-lg font-semibold text-#{tint}-700 capitalize flex items-center gap-2"}>
                <i class={"fa-solid fa-circle text-#{tint}-500"}></i>
                <%= tint %>
              </h3>
              <span class={"badge badge-sm bg-#{tint}-100 text-#{tint}-700"}>
                <%= length(get_queries_by_tint(@queries, tint)) %>
              </span>
            </div>
            
            <div class="space-y-2 max-h-64 overflow-y-auto">
              <%= for query <- get_queries_by_tint(@queries, tint) do %>
                <div class={"query-item p-2 rounded bg-#{tint}-50 border border-#{tint}-200 hover:bg-#{tint}-100 transition-colors"}>
                  <div class="flex items-center gap-2">
                    <span class="tooltip tooltip-primary" data-tip={query.source.type}>
                      <i class={"fas fa-fw #{get_icon(query.source.type)}"}></i>
                    </span>
                    <div class="flex-1 min-w-0">
                      <div class={"text-sm font-medium text-#{tint}-800 truncate"}>
                        <%= query.name %>
                      </div>
                      <div class={"text-xs text-#{tint}-600 truncate"}>
                        <%= query.source.name %>
                      </div>
                    </div>
                    <div class="flex items-center gap-1">
                      <%= render_tint_indicator(query, tint) %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
            
            <%= if @on_tint_select do %>
              <div class="mt-3 pt-3 border-t border-gray-200">
                <button 
                  class={"btn btn-sm btn-outline w-full text-#{tint}-600 border-#{tint}-300 hover:bg-#{tint}-100"}
                  phx-click={@on_tint_select}
                  phx-value-tint={tint}
                >
                  <%= if @selected_tint == tint do %>
                    <i class="fa-solid fa-eye-slash mr-1"></i>
                    Clear Filter
                  <% else %>
                    <i class="fa-solid fa-filter mr-1"></i>
                    Filter by <%= tint %>
                  <% end %>
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
        
        <%= if length(@available_tints) == 0 do %>
          <div class="col-span-full text-center py-8 text-gray-500">
            <i class="fa-solid fa-palette text-4xl mb-2"></i>
            <p>No tinted queries found</p>
            <p class="text-sm">Add tints to your queries and sources to see them organized here</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper function to get queries by tint
  defp get_queries_by_tint(queries, tint) do
    queries
    |> Enum.filter(fn query ->
      (query.meta && query.meta.tint == tint) || 
      (query.source && query.source.meta && query.source.meta.tint == tint)
    end)
  end

  # Helper to render tint indicators (similar to the table view)
  defp render_tint_indicator(query, _current_tint) do
    case {query.meta && query.meta.tint, query.source && query.source.meta && query.source.meta.tint} do
      {query_tint, source_tint} when query_tint != nil and source_tint != nil ->
        # Both query and source tints - use fa-stack
        assigns = %{query_tint: query_tint, source_tint: source_tint}
        ~H"""
        <span class="fa-stack text-xs">
          <i class={"fa-solid fa-circle fa-stack-1x text-#{@source_tint}-500"} data-fa-transform="shrink-3"></i>
          <i class={"fa-solid fa-circle fa-stack-1x text-#{@query_tint}-500"} data-fa-transform="shrink-4 right-4"></i>
        </span>
        """
      
      {query_tint, _} when query_tint != nil ->
        # Query tint only
        assigns = %{query_tint: query_tint}
        ~H"""
        <i class={"fa-solid fa-circle text-#{@query_tint}-500 text-xs"} data-fa-transform="shrink-3"></i>
        """
      
      {_, source_tint} when source_tint != nil ->
        # Source tint only  
        assigns = %{source_tint: source_tint}
        ~H"""
        <i class={"fa-solid fa-circle text-#{@source_tint}-500 text-xs"}></i>
        """
      
      _ ->
        # No tints
        assigns = %{}
        ~H""
    end
  end

  # Icon helper (delegate to existing IconHelpers)
  defp get_icon(type) do
    RoomSanctumWeb.IconHelpers.icon(type)
  end
end
