
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


select cp.ref, cp.psc, cp.id, cp.x, cp.y, cp.lat, cp.lon,
       coalesce(cp.address, cp.suburb||', '||cp.village||', '||cp.district) address,
       cp.place, cp.collection_times, cp.last_update, cp.source,
       pb.latitude, pb.longitude, pb.ref, pb.operator, pb.collection_times,
from cp_post_boxes cp
     LEFT OUTER JOIN post_boxes pb
     ON cp.ref = pb.ref
where psc = 29000
order by id;



