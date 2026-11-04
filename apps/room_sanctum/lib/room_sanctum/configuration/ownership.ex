defmodule RoomSanctum.Configuration.Ownership do
  @moduledoc """
  A record may only point at its owner's own records.

  The forms only offer the user's own sources, queries, visions and so on, but
  a form is not the only way in: whatever ids the client sends are cast as
  they come. These check them against the owner of the record being saved.

  Only the ids a change *adds* are checked. Stored records can already hold
  ids with nothing behind them -- deleting a record does not take its id off
  everything that pointed at it -- and those have to stay editable. A record
  with no owner is left alone, as `Vision`'s `query_ids` check does.
  """
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias RoomSanctum.Repo

  @message "must be your own"

  @doc """
  Refuse the change if `field` -- an id, or a list of them -- gains an id of a
  `schema` row the record's owner does not own.
  """
  def validate_owned(changeset, field, schema) do
    added = List.wrap(get_change(changeset, field)) -- List.wrap(Map.get(changeset.data, field))
    check(changeset, field, added, schema)
  end

  @doc """
  The same, for an id kept in an embed: `key` inside the `embed` field, as a
  query keeps its `foci_id` and a packages source its `mailbox_source_id`.
  """
  def validate_owned_in(changeset, embed, key, schema) do
    case get_change(changeset, embed) do
      nil ->
        changeset

      new ->
        old = embedded(Map.get(changeset.data, embed), key)
        check(changeset, embed, List.wrap(embedded(new, key)) -- List.wrap(old), schema)
    end
  end

  defp embedded(%Ecto.Changeset{} = changeset, key), do: get_field(changeset, key)
  defp embedded(%{} = struct, key), do: Map.get(struct, key)
  defp embedded(nil, _key), do: nil

  defp check(changeset, field, added, schema) do
    with [_ | _] = ids <- added |> Enum.reject(&is_nil/1) |> Enum.uniq(),
         user_id when not is_nil(user_id) <- get_field(changeset, :user_id),
         [_ | _] <- ids -- owned_ids(schema, ids, user_id) do
      add_error(changeset, field, @message)
    else
      _ -> changeset
    end
  end

  defp owned_ids(schema, ids, user_id) do
    Repo.all(from r in schema, where: r.id in ^ids and r.user_id == ^user_id, select: r.id)
  end
end
