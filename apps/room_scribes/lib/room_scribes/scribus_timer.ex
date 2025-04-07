defmodule RoomScribus.Timer do
  @moduledoc false
  use GenServer

  use Bitwise

  require Logger

  alias RoomSanctum.Configuration

  @registry :zeus
  @dynamic_refresh_seconds 30

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple("scribus_timer_" <> opts[:name]))
  end

  @impl true
  def init(opts) do
    Process.send_after(self(), :tick, 150)
    Phoenix.PubSub.subscribe(RoomSanctum.PubSub, "scribus:#{opts[:name]}")
    Periodic.start_link(
      every: :timer.seconds(@dynamic_refresh_seconds),
      run: fn -> RoomScribus.Timer.reread(opts[:name]) end,
      initial_delay: 100
    )

    {:ok, %{id: opts[:name], scribus: nil}}
  end

  def reread(name) do
    "scribus_timer_#{name}"
    |> via_tuple()
    |> GenServer.cast(:reread)
  end

  def handle_info(:tick, state) do
    case state.scribus do
      nil ->
        Process.send_after(self(), :tick, 1000)
      value ->
        Process.send_after(self(), :tick, value.buffer * 1000)
        RoomScribe.Worker.request(state.scribus.id |> Integer.to_string)
    end
    {:noreply, state}
  end

  @impl true
  def handle_cast(:reread, state) do
    scribus = Configuration.get_scribus!(state.id)
    {:noreply, state |> Map.put(:scribus, scribus)}
  end

  def handle_info({:update, scan_data}, state) do
    IO.inspect("gottem here")
    png = scan_data.png |> Base.decode64!
#    {:ok, pixels} = Pixels.read(png) |> IO.inspect
#    as_grayscale = to_grayscale_again(pixels) |> IO.inspect
#    filled = fill_from_array(pixels.height, pixels.width, as_grayscale)
#    RoomSanctum.Worker.Ankyra.publish_img(state.scribus.ankyra, scan_data |> Map.put(:png, :binary.bin_to_list(filled) |> to_string()))
    {:noreply, state}
  end

  def fill_from_array(height, width, pixel_list) do
    # Create an empty framebuffer (a binary of the appropriate size)
    fb = :binary.copy(<<0>>, div(width * height, 2))

    # Iterate over each pixel in the list and update the framebuffer
    Enum.reduce_while(pixel_list, fb, fn {x, y, color}, acc ->
      if x >= 0 and x < width and y >= 0 and y < height do
        # Update the framebuffer with the current pixel
        acc = pixel(acc, width, height, x, y, color)
        {:cont, acc}
      else
        {:cont, acc}  # Continue, but don't modify the framebuffer if out of bounds
      end
    end)
  end

  def to_grayscale_again(%{data: data} = pixels) do
    grayscale_data =
      data
      |> :binary.bin_to_list()
      |> Enum.chunk_every(4)
      |> Enum.map(fn [r, g, b, _a] -> div(r + g + b, 3) end)
      |> :binary.list_to_bin()

    grayscale_data
  end

  def pixel(width, height, fb, x, y, color) do
    if x < 0 or x >= width or y < 0 or y >= height do
      fb
    else
      color = 255 - color
      pos = y * div(width, 2) + div(x, 2)

      existing_byte = :binary.at(fb, pos) || 0

      new_byte =
        if rem(x, 2) == 1 do
          (existing_byte &&& 0x0F) ||| (color &&& 0xF0)
        else
          (existing_byte &&& 0xF0) ||| ((color >>> 4) && 0x0F)
        end

      updated_fb = put_byte(fb, pos, new_byte)

      updated_fb
    end
  end

  defp put_byte(fb, pos, value) do
    <<prefix::binary-size(pos), _::8, suffix::binary>> = fb
    <<prefix::binary, value::8, suffix::binary>>
  rescue
    _ -> fb
  end

  defp via_tuple(name), do: {:via, Registry, {@registry, name}}
end