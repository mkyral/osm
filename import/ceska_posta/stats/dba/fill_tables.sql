

-- Fill data from osm schema

truncate table post_boxes;
insert into post_boxes (id, create_date)
    select node_id, current_timestamp from current_node_tags where k = 'amenity' and v = 'post_box';

update post_boxes pb set (latitude, longitude) = (select latitude, longitude from current_nodes c where c.id = pb.id);
update post_boxes pb set ref = (select v from current_node_tags c where c.node_id = pb.id and c.k = 'ref');
update post_boxes pb set collection_times = (select v from current_node_tags c where c.node_id = pb.id and c.k = 'collection_times');
update post_boxes pb set operator = (select v from current_node_tags c where c.node_id = pb.id and c.k = 'operator');
