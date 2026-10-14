defmodule RoomGtfs.Fleet do
  @moduledoc """
  Whether a vehicle is one of the ones a source has asked to have called out.

  The rules are a source's `fleet_marks`: route id to inclusive car-number
  ranges. A train is marked when any of its cars is in range for the route it
  is running on, which is how the new-train-tracker reads a mixed consist --
  one new car is a new train to someone looking for it.

  Car numbers come from the feed's own per-carriage labels where it sends
  them, and otherwise from the vehicle's label, which the MBTA writes as the
  cars joined by hyphens: "1877-1876". A label that is not a number is no car
  of anyone's fleet and simply never matches.
  """

  @doc """
  The rules for a route, or nil where there are none -- so a source that set
  none, or a route it did not mention, costs nothing further.
  """
  def rules_for(config, route_id) when is_binary(route_id) do
    case config && Map.get(config, :fleet_marks) do
      marks when is_map(marks) and map_size(marks) > 0 ->
        case Map.get(marks, route_id) do
          ranges when is_list(ranges) and ranges != [] -> ranges
          _ -> nil
        end

      _ ->
        nil
    end
  end

  def rules_for(_config, _route_id), do: nil

  @doc "Whether a car label falls in any of the ranges."
  def car_marked?(label, ranges) do
    case car_number(label) do
      nil -> false
      n -> Enum.any?(ranges, fn [low, high] -> n >= low and n <= high end)
    end
  end

  @doc """
  The car labels of a vehicle as `place_vehicle/2` records it: its carriages'
  labels if it reported any, else its own label split into cars.
  """
  def car_labels(vehicle) do
    carriage_labels =
      vehicle
      |> Map.get(:carriages)
      |> List.wrap()
      |> Enum.map(& &1.label)
      |> Enum.filter(&(is_binary(&1) and &1 != ""))

    case carriage_labels do
      [] ->
        case Map.get(vehicle, :label) do
          label when is_binary(label) -> label |> String.split("-") |> Enum.map(&String.trim/1)
          _ -> []
        end

      labels ->
        labels
    end
  end

  @doc "Whether any of a vehicle's cars is in range."
  def vehicle_marked?(vehicle, ranges) do
    vehicle |> car_labels() |> Enum.any?(&car_marked?(&1, ranges))
  end

  defp car_number(label) when is_binary(label) do
    case Integer.parse(String.trim(label)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp car_number(_label), do: nil
end
