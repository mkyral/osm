\t
-- Fill osm data from osm schema
\echo '----------------------------------------------------------------------------'
select 'Compute stats - '||to_char(current_timestamp, 'YYYYMMDD HH24:MI:SS');
\echo '----------------------------------------------------------------------------'

\timing on

\echo
\echo '* Compute stats'
\echo '** Add new depos'

insert into cp_stats
    select distinct psc from cp_post_boxes
    UNION
    select '0' -- total values
    EXCEPT
    select distinct depo from cp_stats
    ;


\echo
\echo '** Compute totals per depo'

WITH totals as (
  select s.depo,
    (select count(1) from cp_post_boxes cp where cp.psc = s.depo and state = 'A') cp_total,
    (select cp_total from cp_stats ps where ps.depo = s.depo) prev_cp_total,
    (select count(1) from cp_post_boxes cp where cp.psc = s.depo and x IS NULL and state = 'A') cp_missing,
    (select cp_missing from cp_stats ps where ps.depo = s.depo) prev_cp_missing,
    (select count(1) from cp_post_boxes cp, osm_post_boxes pb where cp.psc = s.depo and cp.ref = pb.ref) osm_linked,
    (select osm_linked from cp_stats ps where ps.depo = s.depo) prev_osm_linked
  from cp_stats s
)
update cp_stats cps
set (cp_total, cp_missing, osm_linked, prev_cp_total, prev_cp_missing, prev_osm_linked) =
(select cp_total, cp_missing, osm_linked, prev_cp_total, prev_cp_missing, prev_osm_linked from totals t where t.depo = cps.depo)
;

\echo
\echo '** Compute global totals'

update cp_stats cps
set (cp_total, cp_missing, osm_linked) =
(select sum(coalesce(cp_total, 0)), sum(coalesce(cp_missing, 0)), sum(coalesce(osm_linked, 0))
 from cp_stats  where depo <> 0)
where depo = 0;

update cp_stats cps
set osm_total = (select count(1) from osm_post_boxes pb)
where depo = 0;

update cp_stats cps
set (cp_timestamp, osm_timestamp) =
(select cp, osm from cp_data_state limit 1);

\echo
\echo '** Update timestamp'
update cp_data_state set stats = current_timestamp;


\timing off

\echo
\echo '----------------------------------------------------------------------------'
select 'Done - '||to_char(current_timestamp, 'YYYYMMDD HH24:MI:SS');
\echo '----------------------------------------------------------------------------'
