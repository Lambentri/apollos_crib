defmodule RoomSanctum.SentryClient do
  @moduledoc """
  Sentry's HTTP client, for hackney 4.

  Sentry 8 ships `Sentry.HackneyClient`, which reads the response with
  `:hackney.body/1` -- a call that only takes a connection pid from hackney 3
  on, where the body comes back in the response itself. Left as the default,
  every event Sentry tried to send would crash the task sending it, and errors
  would quietly stop arriving.

  The same pool and options as Sentry's own client otherwise, so the
  `:hackney_pool_max_connections`, `:hackney_pool_timeout` and `:hackney_opts`
  settings keep meaning what they did.
  """

  @behaviour Sentry.HTTPClient

  @pool :sentry_pool

  @impl true
  def child_spec do
    {:ok, _} = Application.ensure_all_started(:hackney)

    :hackney_pool.child_spec(@pool,
      timeout: Sentry.Config.hackney_timeout(),
      max_connections: Sentry.Config.max_hackney_connections()
    )
  end

  @impl true
  def post(url, headers, body) do
    opts = Keyword.put_new(Sentry.Config.hackney_opts(), :pool, @pool)

    case :hackney.request(:post, url, headers, body, opts) do
      {:ok, status, resp_headers, resp_body} -> {:ok, status, resp_headers, resp_body}
      {:ok, status, resp_headers} -> {:ok, status, resp_headers, ""}
      {:error, reason} -> {:error, reason}
    end
  end
end
