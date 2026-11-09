defmodule RoomSanctum.Repo.Migrations.AddTintLabels do
  use Ecto.Migration

  @moduledoc """
  Subgrouping within a tint.

  A colour runs out as a grouping the moment it means "everything about
  getting to work" and half of that is buses and half is bikes. The label is
  the subgroup, and a Plani can narrow a follow to some of them rather than
  taking the whole colour.

  Only foci and the Plani need columns: a source, query and vision each keep
  their tint in a `meta` jsonb, and an embed gains a field without the table
  hearing about it.
  """

  def change do
    alter table(:cfg_focis) do
      add :tint_label, :string
    end

    alter table(:cfg_plani) do
      # Plural, because a follow narrows to a set of subgroups. Empty is the
      # whole tint, which is what every existing follow means and what it
      # goes on meaning.
      add :follow_tint_labels, {:array, :string}, default: []
      add :home_tint_labels, {:array, :string}, default: []
    end
  end
end
