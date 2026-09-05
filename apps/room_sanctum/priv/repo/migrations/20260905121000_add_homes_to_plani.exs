defmodule RoomSanctum.Repo.Migrations.AddHomesToPlani do
  use Ecto.Migration

  @moduledoc """
  More than one home, and a say in how long before it goes there.

  A Plani had one home foci and settled on it whenever the client went quiet.
  One home is wrong for anybody who has two -- a house and an office -- since
  the useful answer is whichever of them you were last near, not whichever was
  configured first.

  `home_foci_id` stays as the first home and the fallback for a Plani that has
  never heard a position, so nothing needs migrating.
  """

  def change do
    alter table(:cfg_plani) do
      add :home_foci_ids, {:array, :integer}, default: [], null: false
      add :home_tint, :string
      add :home_after_mins, :integer, default: 5, null: false
    end
  end
end
