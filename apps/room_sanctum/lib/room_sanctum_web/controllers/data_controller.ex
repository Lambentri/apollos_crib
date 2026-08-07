defmodule RoomSanctumWeb.DataController do
  use RoomSanctumWeb, :controller

  alias LambentEx.API
  @pubsub_name RoomSanctum.PubSub
  @pubsub_topic "webhooks"

  action_fallback RoomSanctumWeb.FallbackController

  require Logger

  def index(conn, data) do
    {path, data} = data |> Map.pop("path")
    {:ok, datas, _conn_details} = Plug.Conn.read_body(conn)
    IO.inspect(datas)

#    IO.inspect({"PDPDPD", path, data})
#    %{path: path, data: datas}
#    |> RoomSanctum.Queues.Webhooks.new()
#    |> Oban.insert()

#    LambentEx.Meta.get_http()
#    |> Enum.map(fn {name, hpath} ->
#      case {name, hpath} do
#        {name, ^path} -> Phoenix.PubSub.broadcast(@pubsub_name, @pubsub_topic, {name, path, data})
#        {name, _path} -> :ok
#      end
#    end)

    text(conn, :ok)
  end

  def create(conn, data) do
    {path, data} = data |> Map.pop("path")

    # USPS signs its notifications; the header has to reach the queue for the
    # signature to be checkable there.
    hmac =
      case Plug.Conn.get_req_header(conn, "x-hmac") do
        [value | _] -> value
        [] -> List.first(Plug.Conn.get_req_header(conn, "hmac-header"))
      end
#    IO.inspect(data)
#    {:ok, datas, _conn_details} = Plug.Conn.read_body(conn)
#    IO.inspect(datas)
    %{path: path, data: data, hmac: hmac}
    |> RoomSanctum.Queues.Webhooks.new()
    |> Oban.insert()

#    # LambentEx.Meta.get_http()
#    |> Enum.map(fn {name, hpath} ->
#      case {name, hpath} do
#        {name, ^path} -> Phoenix.PubSub.broadcast(@pubsub_name, @pubsub_topic, {name, path, data})
#        {name, _path} -> :ok
#      end
#    end)

    text(conn, :ok)
  end
end
