
-- total stats
select cp_total,
       cp_missing, (cp_missing::float*100/cp_total::float)::numeric(6,2) cp_missing_pct,
       osm_linked, (osm_linked::float*100/cp_total::float)::numeric(6,2) osm_linked_pct
from ( select
        (select count(1) from cp_post_boxes cp ) cp_total,
        (select count(1) from cp_post_boxes cp where x IS NULL) cp_missing,
        (select count(1) from cp_post_boxes cp, post_boxes pb where cp.ref = pb.ref) osm_linked) t;


-- total per depot
select psc, name, cp_total,
       cp_missing, (cp_missing::float*100/cp_total::float)::numeric(6,2) cp_missing_pct,
       osm_linked, (osm_linked::float*100/cp_total::float)::numeric(6,2) osm_linked_pct
from ( select d.psc, d.name,
        (select count(1) from cp_post_boxes cp where cp.psc = d.psc) cp_total,
        (select count(1) from cp_post_boxes cp where cp.psc = d.psc and x IS NULL) cp_missing,
        (select count(1) from cp_post_boxes cp, post_boxes pb where cp.psc = d.psc and cp.ref = pb.ref) osm_linked
      from cp_depos d) s;


-- Depot data

WITH depo_data AS (
select cp.ref, cp.state, cp.psc, cp.id, cp.x, cp.y, cp.lat, cp.lon,
       coalesce(cp.address, cp.suburb||', '||cp.village||', '||cp.district) address,
       cp.place, cp.collection_times cp_collection_times, cp.last_update, cp.source,
       pb.id osm_id, pb.latitude/10000000 as osm_lat, pb.longitude/10000000 as osm_lon,
       CASE WHEN cp.lon IS NOT NULL and pb.longitude IS NOT NULL
              THEN
                ST_DistanceSphere(st_makepoint(cp.lon, cp.lat),
                                  st_makepoint(pb.longitude/10000000, pb.latitude/10000000))
            ELSE NULL
       END as distance,
       pb.ref osm_ref, pb.operator as osm_operator,
       pb.collection_times osm_collection_times, pb.fixme as osm_fixme,
       (select count(1) from osm_post_boxes where ref = cp.ref) as osm_links_count
from cp_post_boxes cp
     LEFT OUTER JOIN osm_post_boxes pb
     ON cp.ref = pb.ref
where psc = 37271
order by cp.id)
select ref, psc, id, x, y, lat, lon, address, place, cp_collection_times, last_update, source,
       osm_id, osm_lat, osm_lon, distance,
       CASE WHEN distance is NULL THEN NULL
            WHEN distance >= 1000 THEN to_char(distance / 1000.0, 'FM999999999.00')||' km'
            WHEN distance >= 1 THEN to_char(distance, 'FM999999999.00')||' m'
            ELSE to_char(distance * 100.0, 'FM999999999.00')||' cm'
       END as distance_formated,
       osm_ref, osm_operator, osm_collection_times, osm_fixme,
       osm_links_count,
       CASE WHEN osm_id IS NOT NULL and state = 'D' THEN 'Deleted'
            WHEN osm_id IS NULL and state = 'A' THEN 'Missing'
            WHEN osm_id IS NOT NULL
             and state = 'A'
             and cp_collection_times = osm_collection_times
             and coalesce(osm_operator, 'xxx') = 'Česká pošta, s.p.'
             and osm_fixme IS NULL
             and coalesce(distance, 0) < 1000
             and coalesce(osm_links_count, 0) < 2 THEN 'OK'
            WHEN osm_id IS NOT NULL and state = 'A' THEN 'Partial'
            ELSE 'Deleted'
       END as state
from depo_data;

