# Credo's default checks, with two changes: functions may nest one level
# deeper than the default, and @moduledoc isn't required.
# CI runs `mix credo` as a warning (.forgejo/workflows/credo.yml).
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: %{
        extra: [{Credo.Check.Refactor.Nesting, [max_nesting: 3]}],
        disabled: [{Credo.Check.Readability.ModuleDoc, []}]
      }
    }
  ]
}
