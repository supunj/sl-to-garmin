select
	count(*)
from
	nodes
where
	tags @> '"amenity"=>"place_of_worship"' :: hstore
	and tags @> '"religion"=>"buddhist"' :: hstore 

	
select
	tags->'amenity'
from
	nodes
where
	tags ? 'amenity' 	


select
	tags->'shop',
	count(id) as how_many
from
	nodes
where
	tags notnull
	and tags ? 'shop'
group by
	tags->'shop'
order by
	how_many desc
	
select
	tags->'natural',
	count(id) as how_many
from
	nodes
where
	tags notnull
	and tags ? 'natural'
group by
	tags->'natural'
order by
	how_many desc
	
select
	tags->'power',
	count(id) as how_many
from
	nodes
where
	tags notnull
	and tags ? 'power'
group by
	tags->'power'
order by
	how_many desc
	
select *
from nodes
where tags @> '"waterway"=>"waterfall"' :: hstore

select *
from nodes
where tags @> '"natural"=>"waterfall"' :: hstore


select
	tl.key,
	count(*) as cnt
from
	(
	select
		(each(n.tags)).*
	from
		nodes n ) tl
group by
	tl.key
order by
	cnt desc
	
select
	*
from
	(
	select
		(each(n.tags)).*
	from
		nodes n) tgs
where
	tgs.value = 'waterfall'
	
	
select
	*
from
	(
	select
		(each(n.tags)).*
	from
		nodes n) tgs
where
	tgs.value = 'ruins'
	
select
	*
from
	(
	select
		(each(n.tags)).*
	from
		nodes n) tgs
where
	tgs.value = 'grocery'
	
	
	
	
select
	tags->'highway',
	count(id) as how_many
from
	nodes
where
	tags notnull
	and tags ? 'highway'
group by
	tags->'highway'
order by
	how_many desc

select
	tags->'place',
	tags->'amenity',
	count(id) as how_many
from
	nodes
where
	tags notnull
	and tags ? 'place' or tags ? 'amenity'
group by
	tags->'place', tags->'amenity'
order by
	how_many desc
	
select tags 
from nodes n 
group by tags ? * 

select
	tags->'amenity',
	count(id) as how_many
from
	nodes
where
	tags notnull
	and tags ? 'amenity'
group by
	tags->'amenity'
order by
	how_many desc


select
	n.id
from
	nodes n
where
	n.tags notnull
	and n.id not in (
	select
		distinct wn.node_id
	from
		way_nodes wn)
		
		
select
	tl.key,
	count(*) as cnt
from
	(
	select
		(each(n.tags)).*
	from
		nodes n ) tl
group by
	tl.key
order by
	cnt desc
	
	
select *
from ways w 
where w.tags @> '"natural"=>"waterfall"' :: hstore


select
	w.tags -> 'highway',
	count(*) as cnt,
	round(avg(case when w.tags -> 'maxspeed' ~ '^[0-9\.]+$' then cast(w.tags -> 'maxspeed' as INTEGER) else 0 end))
from
	ways w
where
	w.tags ? 'highway'
group by
	w.tags -> 'highway'
order by
	cnt desc
	

select
	avg(cast(w.tags -> 'maxspeed' as INTEGER))
from
	ways w
where
	w.tags @> '"highway"=>"motorway"' :: hstore

	
	select '12.41212' ~ '^[0-9\.]+$'
	
	
select
	*
from
	ways w
where
	w.tags @> '"highway"=>"trunk"' :: hstore
	
	
select *
from relations r 
where r.tags ? 'landuse'

select distinct r.tags ? 'type'
from relations r 

select
	tags->'landuse',
	count(id) as how_many
from
	relations
where
	tags ? 'landuse'
group by
	tags -> 'landuse'
order by
	how_many desc

	
select
	tags->'natural',
	count(id) as how_many
from
	relations
where
	tags ? 'natural'
group by
	tags -> 'natural'
order by
	how_many desc
	
	
select
	tags->'building',
	count(id) as how_many
from
	ways
where
	tags ? 'building'
group by
	tags -> 'building'
order by
	how_many desc
	

select count(*)
from ways w 
where tags ? 'area'



select count(*)
from ways
where nodes[1] = nodes[array_length(nodes, 1)] and array_length(nodes, 1) > 2



select
	tl.key,
	count(*) as cnt
from
	(
	select
		(each(w.tags)).*
	from
		ways w
	where
		w.nodes[1] = w.nodes[array_length(w.nodes, 1)]
		and array_length(w.nodes, 1) > 2 ) tl
group by
	tl.key
order by
	cnt desc
	
	
select
	tl.key,
	count(*) as cnt
from
	(
	select
		(each(w.tags)).*
	from
		ways w
	where
		w.nodes[1] = w.nodes[array_length(w.nodes, 1)]
		and array_length(w.nodes, 1) > 2 ) tl
group by
	tl.key
order by
	cnt desc
	
	
	
select
	(hstore_to_array(w.tags))[1],
	(hstore_to_array(w.tags))[2]
from
	ways w
where
	w.nodes[1] = w.nodes[array_length(w.nodes, 1)]
	and array_length(w.nodes, 1) > 2
	and (hstore_to_array(w.tags))[1] <> 'name'
	
	
select
	(hstore_to_array(w.tags))[1] as t1,
	(hstore_to_array(w.tags))[2] as t2,
	count(*) as cnt
from
	ways w
where
	w.nodes[1] = w.nodes[array_length(w.nodes, 1)]
	and array_length(w.nodes, 1) > 2
	and (hstore_to_array(w.tags))[1] not in ('name','source')
group by
	(hstore_to_array(w.tags))[1] ,
	(hstore_to_array(w.tags))[2]
having
	count(*) > 9
order by
	t1,
	cnt desc
	
select *
from ways w 
where w.tags @> '"building"=>"abandoned"' :: hstore


select *
from ways w 
where w.tags @> '"water"=>"lagoon"' :: hstore

select *
from ways w 
where w.tags @> '"landuse"=>"plant_nursery"' :: hstore


select *
from ways w 
where w.tags @> '"crop"=>"ofc"' :: hstore

select *
from ways w 
where w.tags ? 'crop' and not exist(w.tags, 'landuse')


select
	*
from
	ways w
where
	w.tags @> '"waterway"=>"dam"' :: hstore
	and w.nodes[1] = w.nodes[array_length(w.nodes, 1)]
	and array_length(w.nodes, 1) > 2
	
	
select *
from ways w 

select *
from relations r 
where r.tags @> '"natural"=>"bare_rock"' :: hstore


select *
from relations r 
where r.user_id =813936

select *
from relations r 
where r.tags @> '"natural"=>"bay"' :: hstore

select *
from ways w 
where w.tags @> '"man_made"=>"pipeline"' :: hstore