defmodule RoomGitlab.WorkerTest do
  @moduledoc """
  The GitLab poll, against a stand-in for the API.

  Responses come back as HTTPoison async messages tagged with the request's id,
  and the worker files each body under whatever it recorded for that id. On
  hackney 4 that id is the connection's pid, and a connection from hackney's
  shared pool carries every concurrent request to the same HTTP/2 host, so all
  of them arrive under one id.
  """
  use ExUnit.Case, async: false

  alias RoomGitlab.Worker
  alias RoomSanctum.Configuration.Configs.Gitlab

  defmodule FakeGitlab do
    @moduledoc false
    # Answers a project's jobs with one job that names the project, once the
    # test lets the request through.
    import Plug.Conn

    def init(opts), do: opts

    def call(%{path_info: ["api", "v4", "projects", id, "jobs"]} = conn, opts) do
      send(opts[:test], {:holding, self()})

      receive do
        :go -> :ok
      end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!([%{"id" => id, "status" => "success"}]))
    end
  end

  setup do
    start_supervised!(
      {Plug.Cowboy, scheme: :http, plug: {FakeGitlab, test: self()}, options: [port: 0]}
    )

    port = :ranch.get_port(FakeGitlab.HTTP)
    :ok = :hackney_pool.start_pool(:default, [])

    state = %{
      id: "1",
      inst: %{
        id: 1,
        enabled: true,
        config: %Gitlab{url: "http://127.0.0.1:#{port}", pat: "token"}
      },
      projects: [],
      available_projects: [],
      commits: %{},
      jobs: %{},
      refs: %{},
      refs_t: %{},
      refs_i: %{}
    }

    %{state: state}
  end

  test "job requests each open a connection of their own", %{state: state} do
    {:noreply, state} = query_jobs(state, [11, 22])
    held = for _ <- 1..2, do: assert_receive({:holding, _pid}, 5_000)

    # Both requests are in flight, and neither came out of the shared pool.
    assert :hackney_pool.get_stats(:default)[:in_use_count] == 0

    for {:holding, pid} <- held, do: send(pid, :go)
    responses = receive_responses(2)
    state = Enum.reduce(responses, state, &handle_info/2)

    assert state.jobs == %{
             11 => [%{"id" => "11", "status" => "success"}],
             22 => [%{"id" => "22", "status" => "success"}]
           }

    # Nor do those connections outlast their responses.
    for conn <- responses |> Enum.map(& &1.id) |> Enum.uniq() do
      ref = Process.monitor(conn)
      assert_receive {:DOWN, ^ref, :process, ^conn, _}
    end
  end

  test "a GitLab it can't reach skips the poll instead of crashing", %{state: state} do
    # A port nothing listens on: the request fails before it starts.
    {:ok, sock} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(sock)
    :ok = :gen_tcp.close(sock)
    state = put_in(state.inst.config.url, "http://127.0.0.1:#{port}")

    assert {:noreply, state} = query_jobs(state, [11, 22])
    assert state.refs == %{}
  end

  test "what still arrives for a request after its end is dropped", %{state: state} do
    # Its connection, already gone.
    conn = spawn(fn -> :ok end)
    {:ok, fd} = StringIO.open("")
    state = %{state | refs: %{conn => %{fd: fd, type: :jobs, id: 22}}}

    state =
      Enum.reduce(
        [
          %HTTPoison.AsyncStatus{id: conn, code: 200},
          %HTTPoison.AsyncChunk{id: conn, chunk: ~s([{"id":"22"}])},
          %HTTPoison.AsyncEnd{id: conn},
          # A second response under the same id, as two requests sharing a
          # connection used to bring.
          %HTTPoison.AsyncStatus{id: conn, code: 503},
          %HTTPoison.AsyncChunk{id: conn, chunk: "unavailable"},
          %HTTPoison.AsyncEnd{id: conn},
          %HTTPoison.Error{id: conn, reason: :closed}
        ],
        state,
        &handle_info/2
      )

    assert state.jobs == %{22 => [%{"id" => "22"}]}
    assert state.refs == %{}
  end

  test "a message it has no use for is ignored", %{state: state} do
    redirect = %HTTPoison.AsyncRedirect{id: self(), to: "https://example.com/", headers: []}

    assert Worker.handle_info(:unexpected, state) == {:noreply, state}
    assert Worker.handle_info(redirect, state) == {:noreply, state}
  end

  defp query_jobs(state, project_ids) do
    projects = for id <- project_ids, do: %{"id" => id}
    Worker.handle_cast({:query_jobs, %{}}, %{state | projects: projects})
  end

  defp handle_info(msg, state) do
    {:noreply, state} = Worker.handle_info(msg, state)
    state
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
      5_000 -> flunk("no complete response from the fake GitLab")
    end
  end
end
