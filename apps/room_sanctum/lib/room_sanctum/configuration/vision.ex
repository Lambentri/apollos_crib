defmodule RoomSanctum.Configuration.Vision do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cfg_visions" do
    belongs_to :user, RoomSanctum.Accounts.User
    field :name, :string
    field :type, Ecto.Enum, values: [:alerts, :time, :pinned, :background]
    embeds_many :queries, RoomSanctum.Configuration.Vision.Schema, on_replace: :delete
    field :public, :boolean

    embeds_one :meta, Meta, on_replace: :delete, primary_key: :false do
      field :tint, :string
    end

    timestamps()
    field :query_ids, {:array, :integer}
  end

  @doc false
  def changeset(vision, attrs) do
    vision
    |> cast(attrs, [:name, :user_id, :query_ids, :public])
    |> cast_embed(:meta, required: false, with: &meta_changeset/2)
    |> cast_embed(:queries, with: &RoomSanctum.Configuration.Vision.Schema.changeset/2, sort_param: :queries_sort, drop_param: :queries_drop)
    |> foreign_key_constraint(:user_id)
    |> validate_required([:name, :user_id])
    |> validate_queries_have_valid_ids()
  end

  def meta_changeset(meta, attrs \\ %{}) do
    meta
    |> cast(attrs, [:tint])
    |> validate_tint()
  end

  # A tint that is not in the palette has no stylesheet behind it, so it would
  # render as an unstyled dot rather than a colour.
  defp validate_tint(changeset) do
    case get_field(changeset, :tint) do
      nil -> changeset
      "" -> put_change(changeset, :tint, nil)
      tint -> if RoomSanctum.Tints.valid?(tint), do: changeset, else: add_error(changeset, :tint, "unknown colour")
    end
  end

  defp validate_queries_have_valid_ids(changeset) do
    case get_field(changeset, :query_ids) do
      ids when is_list(ids) and length(ids) > 0 ->
        # Validate that all query IDs exist and belong to the user
        changeset
      _ ->
        changeset
    end
  end

end

defmodule RoomSanctum.Configuration.Vision.Schema do
  use Ecto.Schema
  import Ecto.Changeset
  import PolymorphicEmbed

  embedded_schema do
    field :type, Ecto.Enum, values: [:alerts, :time, :pinned, :background]

    polymorphic_embeds_one :data,
      types: [
        alerts: RoomSanctum.Configuration.Vision.Schema0Alerts,
        time: RoomSanctum.Configuration.Vision.Schema1Time,
        pinned: RoomSanctum.Configuration.Vision.Schema2Pinned,
        background: RoomSanctum.Configuration.Vision.Schema3Background
      ],
      on_type_not_found: :raise,
      on_replace: :update
  end

  def changeset(source, params) do
    source
    |> cast(params, [:type])
    |> cast_polymorphic_embed(:data, required: true)
    |> validate_required([:type])
  end
end

defmodule RoomSanctum.Configuration.Vision.Schema0Alerts do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :order, :integer
    field :query, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, [:query, :order])
    |> validate_required([:query, :order])
  end
end

defmodule RoomSanctum.Configuration.Vision.Schema1Time do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :order, :integer
    field :query, :integer
    field :weekdays, {:array, Ecto.Enum}, values: [:U, :M, :T, :W, :R, :F, :S]
    field :time_start, :time
    field :time_end, :time
  end

  def changeset(source, params) do
    source
    |> cast(params, [:query, :order, :weekdays, :time_start, :time_end])
    |> validate_required([:query, :order, :weekdays])
  end
end

defmodule RoomSanctum.Configuration.Vision.Schema2Pinned do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :order, :integer
    field :query, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, [:query, :order])
    |> validate_required([:query, :order])
  end
end

defmodule RoomSanctum.Configuration.Vision.Schema3Background do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :order, :integer
    field :query, :integer
  end

  def changeset(source, params) do
    source
    |> cast(params, [:query, :order])
    |> validate_required([:order])
    |> validate_query_selection()
  end

  defp validate_query_selection(changeset) do
    case get_field(changeset, :query) do
      query when is_integer(query) and query > 0 -> changeset
      query when is_binary(query) and query != "" ->
        case Integer.parse(query) do
          {id, ""} when id > 0 -> put_change(changeset, :query, id)
          _ -> add_error(changeset, :query, "must be a valid query ID")
        end
      _ -> changeset  # Allow empty for new entries
    end
  end
end
