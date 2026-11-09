# Credo's default checks, with two changes: functions may nest one level
# deeper than the default, and @moduledoc isn't required. ExSlop adds its
# recommended checks (https://github.com/elixir-vibe/ex_slop).
# CI runs `mix credo` as a warning (.forgejo/workflows/credo.yml).
%{
  configs: [
    %{
      name: "default",
      plugins: [{ExSlop, []}],
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
        extra: [
          {Credo.Check.Refactor.Nesting, [max_nesting: 3]},
          # Speed checks, which tests don't need: `assert length(x) == 2`
          # says more when it fails than a pattern match does.
          {ExSlop.Check.Refactor.LengthComparison, [files: %{excluded: [~r"(^|/)test/"]}]},
          {ExSlop.Check.Warning.RepoAllThenFilter, [files: %{excluded: [~r"(^|/)test/"]}]},
          {ExSlop.Check.Warning.PathExpandPriv, [files: %{excluded: [~r"(^|/)test/"]}]}
        ],
        disabled: [{Credo.Check.Readability.ModuleDoc, []}]
      }
    }
  ]
}
