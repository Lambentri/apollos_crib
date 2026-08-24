defmodule RoomObservatory.PromEx do
  @moduledoc """
  One PromEx instance covering the whole apollos-crib release.

  ## Why one, and why it lives in its own app

  The release runs both Phoenix apps in a single BEAM node. Two PromEx modules
  would mean two metric stores, two `/metrics` endpoints and two sets of BEAM
  gauges describing the *same* VM — and a pod carries only one
  `prometheus.io/port` annotation, so one of them would go unscraped.

  So it is one module naming both endpoints, both routers and both repos. That
  requires an app that depends on both, which neither Phoenix app does or
  should — hence `room_observatory`.

  ## Why the prefix is `phx`

  PromEx names metrics `[otp_app, :prom_ex, plugin]` by default, which here
  would be `room_observatory_prom_ex_phoenix_*` — a name describing the
  observability app rather than anything anyone wants to graph, and different
  again from the six standalone Phoenix apps in this fleet.

  Every plugin below overrides that to `[:phx, plugin]`, matching angler,
  feedpug, git-gud, neiam-ircd, waxx and camerite exactly. The Kubernetes
  `namespace` label is what separates them, so one dashboard shape describes
  all seven.

  ## The two endpoints are not separated by label

  Worth knowing before reading a panel here, because it is easy to assume
  otherwise: PromEx's HTTP metrics are tagged
  `{status, method, path, controller, action, host}` and that list is hardcoded
  in the plugin. There is **no `endpoint` label**, so room_sanctum's and
  room_hermes's requests land in the same `phx_phoenix_http_requests_total`
  series set and a naive `sum` covers both.

  What separates them in practice is `host`: sanctum is behind the Ingress at
  `ac.neiam.org`, while hermes has a Service and no Ingress, so it is only
  reached in-cluster under a different Host header. That is a property of the
  deployment rather than of the instrumentation, and it stops being true the
  moment hermes gets an Ingress of its own.

  The channel, socket and `endpoint_info` metrics *do* carry an `endpoint`
  label. Only the HTTP ones do not.

  ## Grafana upload is off

  PromEx can push its own dashboards to Grafana on boot. The dashboards for
  this fleet are committed in `deployment/grafana` and pushed from there, so an
  uploaded one would either be reverted by the next sync or quietly win over
  the committed file. Disabled explicitly in `config/config.exs`.
  """

  use PromEx, otp_app: :room_observatory

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      {Plugins.Application, metric_prefix: [:phx, :application]},
      # One VM, so exactly one source of BEAM metrics. This is the plugin that
      # would have double-counted had this been two PromEx modules.
      {Plugins.Beam, metric_prefix: [:phx, :beam]},
      {Plugins.Phoenix,
       endpoints: [
         {RoomSanctumWeb.Endpoint, routers: [RoomSanctumWeb.Router]},
         {RoomHermesWeb.Endpoint, routers: [RoomHermesWeb.Router]}
       ],
       metric_prefix: [:phx, :phoenix]},
      # Both repos report under the same metric names, separated by the `repo`
      # label the Ecto plugin already attaches.
      {Plugins.Ecto, repos: [RoomSanctum.Repo, RoomHermes.Repo], metric_prefix: [:phx, :ecto]},
      # Oban runs under room_sanctum only (see config/config.exs).
      {Plugins.Oban, metric_prefix: [:phx, :oban]},
      # Not a PromEx plugin — see the module. Counts configured sources and the
      # rows they have accumulated, which nothing in the app emits telemetry
      # for, so it asks the database on a timer.
      {RoomObservatory.Plugins.Sanctum, metric_prefix: [:phx, :sanctum]}
    ]
  end
end
