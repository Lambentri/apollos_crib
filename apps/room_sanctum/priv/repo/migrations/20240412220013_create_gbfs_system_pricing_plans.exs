defmodule RoomSanctum.Repo.Migrations.CreateGbfsSystemPricingPlans do
  use Ecto.Migration

  def change do
    create table(:gbfs_system_pricing_plans) do
      add :source_id, references(:cfg_sources, on_delete: :delete_all), null: false
      add :plan_id, :string
      add :name, :string
      add :currency, :string
      add :price, :float
      add :is_taxable, :boolean, default: false, null: false
      add :description, :string
      add :per_min_pricing, :map

      timestamps()
    end

    create index(:gbfs_system_pricing_plans, [:source_id])
    create unique_index(:gbfs_system_pricing_plans, [:source_id, :plan_id])
  end
end
