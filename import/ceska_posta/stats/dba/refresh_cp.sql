

\t
-- Update Post Boxes data from upload table

\echo '----------------------------------------------------------------------------'
select 'Refreshing CP data - '||to_char(current_timestamp, 'YYYYMMDD HH24:MI:SS');
\echo '----------------------------------------------------------------------------'

\timing on

\echo
\echo '* Mark missing records as Deleted'
update cp_post_boxes pb set state = 'D', last_update = current_timestamp
where ref in (select ref from cp_post_boxes EXCEPT select ref from cp_post_boxes_upload)
  and state = 'A';


-- Update existing (if changed)
\echo
\echo '* Update post boxes data'

update cp_post_boxes pb set
( x, y, lat, lon, updated_lat, updated_lon,
  address, place, suburb, village, district, collection_times,
  state, last_update, source) =
( select
    x, y, lat, lon, updated_lat, updated_lon,
    address, place, suburb, village, district, collection_times,
    'A', current_timestamp, source
  from cp_post_boxes_upload pbl
  where pb.ref = pbl.ref)
where ref in (
select pb.ref from cp_post_boxes pb, cp_post_boxes_upload pbl
where pb.ref = pbl.ref
  and
  (
    pb.x != pbl.x or
    pb.y != pbl.y or
    pb.lat != pbl.lat or
    pb.lon != pbl.lon or
    pb.updated_lat != pbl.updated_lat or
    pb.updated_lon != pbl.updated_lon or
    pb.address != pbl.address or
    pb.place != pbl.place or
    pb.suburb != pbl.suburb or
    pb.village != pbl.village or
    pb.district != pbl.district or
    pb.collection_times != pbl.collection_times
  )
);

-- Insert new

\echo
\echo '* Insert new post boxes'
insert into cp_post_boxes
( ref, psc, id, x, y, lat, lon, updated_lat, updated_lon,
  address, place, suburb, village, district, collection_times,
  state, create_date, last_update, source)
select
  ref, psc, id, x, y, lat, lon, updated_lat, updated_lon,
  address, place, suburb, village, district, collection_times,
  'A', current_timestamp, current_timestamp, source
from cp_post_boxes_upload
where ref in (select ref from cp_post_boxes_upload EXCEPT select ref from cp_post_boxes);



-- Update timestamp
update cp_data_state set (cp, cp_source) = (select current_timestamp, source from cp_post_boxes_upload LIMIT 1);
