-- 00_fix_waterfall_tagging.sql
--
-- Normalise waterfall tagging on nodes: OSM's approved tag is
-- waterway=waterfall, but some nodes are (mis)tagged natural=waterfall
-- (see the exploration queries in pg/analysis/queries.sql). The drive66
-- style renders waterway=waterfall, so retag the natural= variant.
--
-- Only touches nodes that have natural=waterfall and no waterway tag
-- already, to avoid clobbering a deliberate double tag.

UPDATE nodes
SET tags = (tags - 'natural'::text) || hstore('waterway', 'waterfall')
WHERE tags @> '"natural"=>"waterfall"' :: hstore
  AND NOT (tags ? 'waterway');
