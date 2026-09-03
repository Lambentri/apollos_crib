defmodule RoomSanctum.Repo.Migrations.AddCurrPlaniToPythiae do
  use Ecto.Migration

  @moduledoc """
  Which Plani a Pythiae is showing, if it is showing one.

  Exclusive with `curr_vision` rather than alongside it: a Plani answers the
  same question a vision does, from wherever its client is, so a Pythiae shows
  one or the other.
  """

  def change do
    alter table(:cfg_pythiae) do
      add :curr_plani, references(:cfg_plani, on_delete: :nilify_all)
    end
  end
end
