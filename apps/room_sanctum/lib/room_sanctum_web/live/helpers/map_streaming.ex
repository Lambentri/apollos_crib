defmodule RoomSanctumWeb.Live.Helpers.MapStreaming do
  @moduledoc """
  High-performance map data streaming helpers for handling large datasets (12,000+ markers)
  
  Based on techniques described in:
  - "Performance optimization when adding 12,000+ markers to the map that renders fast with Elixir, LiveView, and Leaflet.js"
  
  Features:
  - Asynchronous data streaming in chunks
  - Data compression (4x reduction in WebSocket message size)
  - Canvas renderer optimizations
  - Network bandwidth optimization
  """
  
  alias Jason
  
  @doc """
  Stream large datasets to LiveView in optimized chunks
  
  ## Parameters
  - `pid`: LiveView process PID
  - `query_function`: Function that returns data
  - `opts`: Options for streaming
    - `:batch_size` - Number of records per batch (default: 2000)
    - `:total_records` - Total number of records (for optimization)
    - `:compress` - Whether to compress data (default: true)
  
  ## Example
      stream_map_data(self(), &MyContext.list_projects_with_coordinates/2, 
        batch_size: 2000, total_records: 14000, compress: true)
  """
  def stream_map_data(pid, query_function, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 2000)
    total_records = Keyword.get(opts, :total_records, 14000)
    compress = Keyword.get(opts, :compress, true)
    
    batches = div(total_records, batch_size)
    
    # Use Task.async_stream for concurrent processing
    async_stream =
      Task.async_stream(0..(batches - 1), fn batch ->
        current_offset = batch * batch_size
        
        case query_function.(current_offset, batch_size) do
          [] ->
            :done
            
          result ->
            processed_data = if compress do
              compress_data(result)
            else
              result
            end
            
            send(pid, {:map_data_batch, processed_data, batch})
        end
      end, max_concurrency: System.schedulers_online())
    
    async_stream
    |> Stream.run()
    
    # Send completion signal
    send(pid, {:map_streaming_complete})
    
    :done
  end
  
  @doc """
  Compress map data for efficient network transfer
  
  Uses JSON encoding + zlib compression + Base64 encoding
  Achieves ~4x reduction in message size
  """
  def compress_data(data) when is_list(data) do
    # Convert structs to minimal maps and use shortened field names
    compressed_data = 
      data
      |> Enum.map(&minimize_project_data/1)
      |> Jason.encode!()
      |> :zlib.compress()
      |> Base.encode64()
      
    compressed_data
  end
  
  def compress_data(data), do: data
  
  @doc """
  Minimize project data for network transfer
  
  - Remove unused fields
  - Shorten field names
  - Convert to array format for maximum compression
  """
  defp minimize_project_data(%{} = project) do
    # Convert to array format: [name, source, type, lat, lng, tint]
    # This removes field names entirely for maximum compression
    [
      Map.get(project, :name) || Map.get(project, :project_name),
      Map.get(project, :source_name),
      Map.get(project, :type),
      Map.get(project, :latitude) || Map.get(project, :lat),
      Map.get(project, :longitude) || Map.get(project, :lng),
      Map.get(project, :tint)
    ]
  end
  
  defp minimize_project_data(project) when is_map(project) do
    # Handle struct conversion
    project
    |> Map.from_struct()
    |> minimize_project_data()
  end
  
  defp minimize_project_data(project), do: project
  
  @doc """
  Handle streaming data in LiveView mount/3
  
  ## Example in LiveView:
      def mount(_, _, socket) do
        # Start streaming in background
        Task.start_link(fn ->
          MapStreaming.stream_map_data(self(), &MyContext.list_projects_paginated/2,
            batch_size: 2000, total_records: 14000)
        end)
        
        {:ok, socket}
      end
      
      def handle_info({:map_data_batch, compressed_data, batch_num}, socket) do
        socket = push_event(socket, "add_markers_batch", %{
          compressed_data: compressed_data,
          batch: batch_num
        })
        
        {:noreply, socket}
      end
      
      def handle_info({:map_streaming_complete}, socket) do
        socket = push_event(socket, "map_streaming_complete", %{})
        {:noreply, socket}
      end
  """
  def stream_to_liveview_example, do: :see_documentation
  
  @doc """
  Utility function for database queries with pagination
  
  ## Example Context function:
      def list_projects_paginated(offset \\ 0, limit \\ 2000) do
        from p in Project,
          where: not is_nil(p.latitude) and not is_nil(p.longitude),
          limit: ^limit,
          offset: ^offset,
          select: %{
            name: p.name,
            source_name: p.source_name,  
            type: p.type,
            latitude: p.latitude,
            longitude: p.longitude,
            tint: p.tint
          }
        |> Repo.all()
      end
  """
  def query_example, do: :see_documentation
  
  @doc """
  Performance monitoring utilities
  """
  def benchmark_compression(data) when is_list(data) do
    original_size = data |> Jason.encode!() |> byte_size()
    compressed_size = compress_data(data) |> byte_size()
    
    compression_ratio = original_size / compressed_size
    
    %{
      original_size: original_size,
      compressed_size: compressed_size,
      compression_ratio: compression_ratio,
      savings_percent: (1 - compressed_size / original_size) * 100
    }
  end
  
  @doc """
  Measure streaming performance
  """
  def benchmark_streaming(query_function, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)
    
    stream_map_data(self(), query_function, opts)
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    %{
      duration_ms: duration,
      batch_size: Keyword.get(opts, :batch_size, 2000),
      total_records: Keyword.get(opts, :total_records, 14000)
    }
  end
end
