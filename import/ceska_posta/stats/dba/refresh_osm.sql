
\t
-- Fill osm data from osm schema
\echo '----------------------------------------------------------------------------'
select 'Refreshing OSM data - '||to_char(current_timestamp, 'YYYYMMDD HH24:MI:SS');
\echo '----------------------------------------------------------------------------'

\timing on

\echo
\echo '* Clear table'
truncate table osm_post_boxes;

\echo
\echo '* Insert actual post boxes'
insert into osm_post_boxes (id, create_date)
    select node_id, current_timestamp from current_node_tags where k = 'amenity' and v = 'post_box';

\echo
\echo '* Add LatLon data'
update osm_post_boxes pb set (latitude, longitude) = (select latitude, longitude from current_nodes c where c.id = pb.id);

\echo
\echo '* Add Ref data'
update osm_post_boxes pb set ref = (select v from current_node_tags c where c.node_id = pb.id and c.k = 'ref');

\echo
\echo '* Add collection_times data'
update osm_post_boxes pb set collection_times = (select v from current_node_tags c where c.node_id = pb.id and c.k = 'collection_times');

\echo
\echo '* Add Operator data'
update osm_post_boxes pb set operator = (select v from current_node_tags c where c.node_id = pb.id and c.k = 'operator');


\echo
\echo '* Update timestamp'
update cp_data_state set osm = (select osm from import.datatimestamp LIMIT 1);

\timing off

\echo
\echo '----------------------------------------------------------------------------'
select 'Done - '||to_char(current_timestamp, 'YYYYMMDD HH24:MI:SS');
\echo '----------------------------------------------------------------------------'
