defmodule RoomSanctum.VisionQueryBatchTest do
  @moduledoc """
  A vision asks its queries together, and one of them overrunning is its own
  problem rather than everyone's.

  handle_cast(:query_workers) kills the previous task when the next tick
  arrives thirty seconds later. Asked one after another, a round costs the sum
  of every query's latency, so one slow source did not merely arrive late -- it
  took the whole round with it, including answers that had already come back.
  In prod that read as a board with nothing on it and three cancelled
  statements a minute.
  """
  use ExUnit.Case, async: true

  # The shape of the fix rather than the worker itself: query_all_workers is
  # private and reaches half a dozen apps' workers, none of which run here.
  # What is worth pinning is that the strategy has the properties claimed for
  # it, because the previous one did not.
  @concurrency 4
  @timeout_ms 200

  defp run(jobs) do
    jobs
    |> Task.async_stream(
      # Mirrors query_safely/1: each query is wrapped before it reaches the
      # stream, so a raising source is [] rather than an exit that would take
      # the stream with it.
      fn job ->
        try do
          case job do
            {_name, :slow} -> Process.sleep(@timeout_ms * 5)
            {_name, {:ok, v}} -> v
            {_name, :raise} -> raise "boom"
          end
        rescue
          _ -> []
        end
      end,
      max_concurrency: @concurrency,
      timeout: @timeout_ms,
      on_timeout: :kill_task
    )
    |> Enum.zip(jobs)
    |> Enum.map(fn
      {{:ok, v}, {name, _}} -> {name, v}
      {{:exit, _reason}, {name, _}} -> {name, []}
    end)
    |> Enum.into(%{})
  end

  test "a slow query costs only itself" do
    jobs = [{:a, {:ok, [1]}}, {:slowpoke, :slow}, {:c, {:ok, [3]}}]

    result = run(jobs)

    # The whole round used to be discarded. The two that answered now survive.
    assert result[:a] == [1]
    assert result[:c] == [3]
    assert result[:slowpoke] == []
  end

  test "the round costs the slowest query, not the sum of them" do
    jobs = for n <- 1..8, do: {n, :slow}

    {us, _} = :timer.tc(fn -> run(jobs) end)
    ms = us / 1000

    # Eight slow queries, four at a time: two rounds of the timeout, not eight
    # sequential waits.
    assert ms < @timeout_ms * 4,
           "expected the batch to be bounded by concurrency, took #{ms}ms"
  end

  test "results stay matched to the query that produced them" do
    # async_stream is ordered by default, which is what makes the zip sound.
    jobs = for n <- 1..12, do: {n, {:ok, [n]}}

    result = run(jobs)

    assert Enum.all?(1..12, fn n -> result[n] == [n] end)
  end

  test "a raising query is its own failure too" do
    jobs = [{:a, {:ok, [1]}}, {:bad, :raise}]

    result = run(jobs)

    assert result[:a] == [1]
    assert result[:bad] == []
  end
end
