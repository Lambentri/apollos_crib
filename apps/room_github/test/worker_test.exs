defmodule RoomGithub.WorkerTest do
  @moduledoc """
  The GitHub poll, against a stand-in for the API.

  Responses come back as HTTPoison async messages tagged with the request's id,
  and the worker buffers each body under that id. On hackney 4 the id is the
  connection's pid, and a connection from hackney's shared pool carries every
  concurrent request to the same HTTP/2 host, so all of them arrive under one
  id.
  """
  use ExUnit.Case, async: false

  alias RoomGithub.Worker
  alias RoomSanctum.Configuration.Configs.Github

  defmodule FakeGithub do
    @moduledoc false
    # Answers a repo's workflow runs with one run, once the test lets the
    # request through.
    import Plug.Conn

    def init(opts), do: opts

    def call(%{path_info: ["repos", _owner, repo, "actions", "runs"]} = conn, opts) do
      send(opts[:test], {:holding, self()})

      receive do
        :go -> :ok
      end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{"workflow_runs" => [%{"id" => repo}]}))
    end
  end

  setup do
    start_supervised!(
      {Plug.Cowboy, scheme: :http, plug: {FakeGithub, test: self()}, options: [port: 0]}
    )

    port = :ranch.get_port(FakeGithub.HTTP)
    :ok = :hackney_pool.start_pool(:default, [])

    state = %{
      id: "1",
      inst: %{
        id: 1,
        enabled: true,
        config: %Github{api_url: "http://127.0.0.1:#{port}", pat: "token"}
      },
      repos: [%{"full_name" => "octo/a"}, %{"full_name" => "octo/b"}],
      available_repos: [],
      runs: %{},
      jobs: %{},
      refs: %{}
    }

    %{state: state}
  end

  test "run requests each open a connection of their own", %{state: state} do
    {:noreply, state} = Worker.handle_cast(:query_runs, state)
    held = for _ <- 1..2, do: assert_receive({:holding, _pid}, 5_000)

    # Both requests are in flight, and neither came out of the shared pool.
    assert :hackney_pool.get_stats(:default)[:in_use_count] == 0

    for {:holding, pid} <- held, do: send(pid, :go)
    responses = receive_responses(2)

    state =
      Enum.reduce(responses, state, fn msg, state ->
        {:noreply, state} = Worker.handle_info(msg, state)
        state
      end)

    assert state.runs == %{
             "octo/a" => [%{"id" => "a", "repository" => %{"full_name" => "octo/a"}}],
             "octo/b" => [%{"id" => "b", "repository" => %{"full_name" => "octo/b"}}]
           }

    assert state.refs == %{}

    # Nor do those connections outlast their responses.
    for conn <- responses |> Enum.map(& &1.id) |> Enum.uniq() do
      ref = Process.monitor(conn)
      assert_receive {:DOWN, ^ref, :process, ^conn, _}
    end
  end

  # Every message up to the count-th request's end.
  defp receive_responses(count, acc \\ [])
  defp receive_responses(0, acc), do: Enum.reverse(acc)

  defp receive_responses(count, acc) do
    receive do
      %HTTPoison.AsyncEnd{} = msg ->
        receive_responses(count - 1, [msg | acc])

      %struct{} = msg
      when struct in [HTTPoison.AsyncStatus, HTTPoison.AsyncHeaders, HTTPoison.AsyncChunk] ->
        receive_responses(count, [msg | acc])
    after
      5_000 -> flunk("no complete response from the fake GitHub")
    end
  end
end
