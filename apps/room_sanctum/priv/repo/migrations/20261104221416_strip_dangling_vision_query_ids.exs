defmodule RoomSanctum.Repo.Migrations.StripDanglingVisionQueryIds do
  use Ecto.Migration

  @moduledoc """
  Until now, deleting a query left its id behind on every vision it was on:
  in the `query_ids` array the "which visions is this query on" lookups read,
  and in the embedded `queries` list that renders. `delete_query/1` now clears
  both as it deletes; this clears what the old deletes left.

  Plain SQL against the tables, so it does not depend on the schema modules as
  they happen to be when it runs. An embed without a query (a background row
  never given one) is kept; only ids with no query behind them go. Nothing
  else about a vision is touched, and visions with nothing dangling are not
  rewritten.
  """

  @doc false
  # Exposed so the test can run it against rows it planted.
  def cleanup_sql do
    """
    WITH dangling AS (
      SELECT v.id
      FROM cfg_visions v
      WHERE EXISTS (
              SELECT 1 FROM unnest(v.query_ids) AS u(id)
              WHERE NOT EXISTS (SELECT 1 FROM cfg_queries q WHERE q.id = u.id)
            )
         OR (jsonb_typeof(v.queries) = 'array' AND EXISTS (
              SELECT 1 FROM jsonb_array_elements(v.queries) AS e(elem)
              WHERE e.elem->'data'->>'query' IS NOT NULL
                AND NOT EXISTS (
                  SELECT 1 FROM cfg_queries q WHERE q.id::text = e.elem->'data'->>'query'
                )
            ))
    )
    UPDATE cfg_visions v
    SET query_ids = CASE
          WHEN v.query_ids IS NULL THEN NULL
          ELSE (
            SELECT COALESCE(array_agg(u.id ORDER BY u.ord), ARRAY[]::integer[])
            FROM unnest(v.query_ids) WITH ORDINALITY AS u(id, ord)
            WHERE EXISTS (SELECT 1 FROM cfg_queries q WHERE q.id = u.id)
          )
        END,
        queries = CASE
          WHEN jsonb_typeof(v.queries) = 'array' THEN (
            SELECT COALESCE(jsonb_agg(e.elem ORDER BY e.ord), '[]'::jsonb)
            FROM jsonb_array_elements(v.queries) WITH ORDINALITY AS e(elem, ord)
            WHERE e.elem->'data'->>'query' IS NULL
               OR EXISTS (
                 SELECT 1 FROM cfg_queries q WHERE q.id::text = e.elem->'data'->>'query'
               )
          )
          ELSE v.queries
        END
    FROM dangling d
    WHERE v.id = d.id
    """
  end

  def up, do: execute(cleanup_sql())

  # What pointed at nothing cannot be pointed back at it.
  def down, do: :ok
end
