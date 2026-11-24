-- 00_remove_unnecessary_objects.sql
--
-- Remove untagged ways that are not referenced by any relation. Also remove
-- their way_nodes rows so no dangling way-to-node records remain.

WITH empty_ways AS (
    SELECT w.id
    FROM ways AS w
    WHERE (w.tags IS NULL OR w.tags = ''::hstore)
      AND NOT EXISTS (
          SELECT 1
          FROM relation_members AS rm
          WHERE rm.member_type = 'W'
            AND rm.member_id = w.id
      )
),
deleted_way_nodes AS (
    DELETE FROM way_nodes
    WHERE way_id IN (SELECT id FROM empty_ways)
    RETURNING way_id
)
DELETE FROM ways
WHERE id IN (SELECT id FROM empty_ways);

-- Delete orphaned nodes
DELETE FROM public.nodes AS n                                                                                                                                                            
WHERE (n.tags IS NULL OR n.tags = ''::hstore)                                                                                                                                            
        AND NOT EXISTS (                                                                                                                                                                       
            SELECT 1                                                                                                                                                                           
            FROM public.way_nodes AS wn                                                                                                                                                        
            WHERE wn.node_id = n.id                                                                                                                                                            
        )                                                                                                                                                                                      
        AND NOT EXISTS (                                                                                                                                                                       
            SELECT 1                                                                                                                                                                           
            FROM public.relation_members AS rm                                                                                                                                                 
            WHERE rm.member_type = 'N'                                                                                                                                                         
                AND rm.member_id = n.id                                                                                                                                                          
        );