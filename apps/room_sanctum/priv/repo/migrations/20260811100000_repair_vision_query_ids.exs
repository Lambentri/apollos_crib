defmodule RoomSanctum.Repo.Migrations.RepairVisionQueryIds do
  use Ecto.Migration

  @moduledoc """
  A vision records its queries twice: an embedded list that renders, and an id
  array that every "is this query in a vision" lookup uses.

  Pinning a query appended to the embeds but, thanks to `||` binding looser
  than `++`, left the id array alone whenever it was already populated. So the
  second and subsequent queries pinned to any vision rendered but were invisible
  to the query page, which went on offering the vision it was already in --
  and re-pinning duplicated the embed.

  This reconciles the ids to what is actually embedded, and drops embeds
  duplicated by the re-pinning. Nothing already in the id array is removed.
  """

  def up do
    execute("""
    WITH expanded AS (
      SELECT v.id AS vision_id, e.ord, e.elem,
             (e.elem->'data'->>'query')::int AS query_id
      FROM cfg_visions v,
           LATERAL jsonb_array_elements(v.queries) WITH ORDINALITY AS e(elem, ord)
      WHERE jsonb_typeof(v.queries) = 'array'
    ),
    deduped AS (
      SELECT DISTINCT ON (vision_id, query_id) vision_id, ord, elem, query_id
      FROM expanded
      WHERE query_id IS NOT NULL
      ORDER BY vision_id, query_id, ord
    ),
    rebuilt AS (
      SELECT vision_id,
             jsonb_agg(elem ORDER BY ord) AS queries,
             array_agg(query_id ORDER BY ord) AS embedded_ids
      FROM deduped
      GROUP BY vision_id
    )
    UPDATE cfg_visions v
    SET queries = r.queries,
        query_ids = (
          SELECT array_agg(DISTINCT id)
          FROM unnest(r.embedded_ids || COALESCE(v.query_ids, ARRAY[]::integer[])) AS id
        )
    FROM rebuilt r
    WHERE v.id = r.vision_id
    """)
  end

  # The lost ids cannot be un-lost, and would not want to be.
  def down, do: :ok
end
