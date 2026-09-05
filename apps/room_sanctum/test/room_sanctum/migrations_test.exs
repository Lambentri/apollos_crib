defmodule RoomSanctum.MigrationsTest do
  use ExUnit.Case, async: true

  @migrations Path.join([__DIR__, "..", "..", "priv", "repo", "migrations"])

  # What Ecto itself considers a migration: a leading version, then a name.
  # The directory also holds a .formatter.exs, which is not one.
  defp migration_files do
    @migrations
    |> File.ls!()
    |> Enum.filter(&Regex.match?(~r/^\d+_.*\.exs$/, &1))
  end

  test "no two migrations share a version" do
    # Ecto keys schema_migrations on the version alone. Two files with the
    # same number means the first to run records it and the second is skipped
    # -- and then *reports itself up*, because the version it is looked up by
    # is there. Nothing errors, nothing logs, and the column simply does not
    # exist. That cost an afternoon of a Plani crash-looping in production
    # against a table it had been told was migrated.
    duplicates =
      migration_files()
      |> Enum.group_by(fn file -> file |> String.split("_") |> hd() end)
      |> Enum.filter(fn {_version, files} -> length(files) > 1 end)

    assert duplicates == [],
           "these migrations share a version, and all but one will be skipped:\n" <>
             Enum.map_join(duplicates, "\n", fn {version, files} ->
               "  #{version}: #{Enum.join(files, ", ")}"
             end)
  end

  test "every migration is named after a version that sorts" do
    # Ecto runs them in version order, so a name it cannot parse a number out
    # of would run somewhere unpredictable.
    for file <- migration_files() do
      assert {version, "_" <> _rest} = Integer.parse(file)
      assert version > 0, "#{file} has no leading version"
    end

    # And that the filter is not vacuously true.
    assert length(migration_files()) > 10
  end
end
