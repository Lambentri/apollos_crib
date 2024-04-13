defmodule RoomSanctum.Storage.GBFS.V1.SystemPricingPlans do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gbfs_system_pricing_plans" do
    belongs_to :source, RoomSanctum.Configuration.Source
    field :name, :string
    field :description, :string
    field :currency, :string
    field :plan_id, :string
    field :price, :float
    field :is_taxable, :boolean, default: false
    field :per_min_pricing, :map

    timestamps()
  end

  @doc false
  def changeset(system_pricing_plans, attrs) do
    system_pricing_plans
    |> cast(attrs, [:plan_id, :name, :currency, :price, :is_taxable, :description, :per_min_pricing])
    |> foreign_key_constraint(:source_id)
    |> validate_required([:plan_id, :name, :currency, :price, :is_taxable, :description])
  end
end
