defmodule MapMerge do
  # https://elixirforum.com/t/map-merge-shortcut/878/2
  def a ||| b do
    Map.merge(a, b)
  end
end
