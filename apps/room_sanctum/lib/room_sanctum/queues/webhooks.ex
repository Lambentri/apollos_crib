defmodule RoomSanctum.Queues.Webhooks do
  use Oban.Worker, queue: :webhooks

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"path" => path, "data" => data} = args}) do

    case RoomSanctum.Configuration.get_agyr!(:path, path) do
      nil ->
        IO.inspect("non-extant agyr")

      agyr ->
        source = RoomSanctum.Configuration.get_source!(agyr.source_id)
        case agyr.designator do
          "ups_webhook" ->
            number = data |> Map.get("trackingNumber") |> String.strip
            RoomSanctum.Configuration.update_source_meta_tracking(source, number, data)
        end
    end

    #    model = MyApp.Repo.get(MyApp.Business.Man, id)
    #
    #    case args do
    #      %{"in_the" => "business"} ->
    #        IO.inspect(model)
    #
    #      %{"vote_for" => vote} ->
    #        IO.inspect([vote, model])
    #
    #      _ ->
    #        IO.inspect(model)
    #    end

    :ok
  end
end
