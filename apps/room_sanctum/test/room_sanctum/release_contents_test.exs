defmodule RoomSanctum.ReleaseContentsTest do
  @moduledoc """
  Every app in the umbrella has to be listed in the release, or it is simply
  absent from the built image. Nothing fails at compile time -- the crash comes
  later, in production, when something tries to start a worker from the missing
  app:

      ** (ArgumentError) The module RoomPollen.Worker was given as a child to a
         supervisor but it does not exist

  That is how room_pollen and room_drought shipped without being deployable.
  """
  use ExUnit.Case, async: true

  @umbrella_root Path.expand("../../../..", __DIR__)

  defp umbrella_apps do
    @umbrella_root
    |> Path.join("apps")
    |> File.ls!()
    |> Enum.filter(&File.dir?(Path.join([@umbrella_root, "apps", &1])))
    |> Enum.sort()
  end

  defp released_apps do
    source = File.read!(Path.join(@umbrella_root, "mix.exs"))

    ~r/^\s*(room_[a-z_]+):\s*:permanent/m
    |> Regex.scan(source)
    |> Enum.map(fn [_line, app] -> app end)
    |> Enum.sort()
  end

  test "every umbrella app is included in the release" do
    missing = umbrella_apps() -- released_apps()

    assert missing == [],
           """
           These apps exist but are not in the release's applications list in
           mix.exs, so they will not be in the deployed image:

             #{Enum.join(missing, "\n  ")}
           """
  end

  test "the release does not name an app that no longer exists" do
    stale = released_apps() -- umbrella_apps()

    assert stale == [],
           "The release lists apps that are not in apps/: #{Enum.join(stale, ", ")}"
  end
end
