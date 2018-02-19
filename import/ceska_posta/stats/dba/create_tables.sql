create table osm_post_boxes (
    id               bigint,
    latitude         numeric(20),
    longitude        numeric(20),
    ref              character varying(255),
    operator         character varying(255),
    collection_times character varying(255),
    fixme            character varying(255),
    note             character varying(255),
    create_date      timestamp,
    last_update      timestamp
);

create table cp_post_boxes (
    ref varchar(25)  NOT NULL,
    psc numeric(10),
    id numeric(10),
    x numeric(20,4),
    y numeric(20,4),
    lat numeric(20,10),
    lon numeric(20,10),
    updated_lat numeric(20,10),
    updated_lon numeric(20,10),
    address varchar(255),
    place varchar(255),
    suburb varchar(255),
    village varchar(255),
    district varchar(255),
    collection_times varchar(255),
    state varchar(1),
    create_date timestamp,
    last_update timestamp,
    source varchar(255)
);

comment on table cp_post_boxes is 'Czech post office data about post boxes';
comment on column cp_post_boxes.state is 'Row state: A - active, D - deleted';

create table cp_post_boxes_upload (
    ref varchar(25)  NOT NULL,
    psc numeric(10),
    id numeric(10),
    x numeric(20,4),
    y numeric(20,4),
    lat numeric(20,10),
    lon numeric(20,10),
    updated_lat numeric(20,10),
    updated_lon numeric(20,10),
    address varchar(255),
    place varchar(255),
    suburb varchar(255),
    village varchar(255),
    district varchar(255),
    collection_times varchar(255),
    source varchar(255)
);

create table cp_depos (
    psc numeric(10),
    name varchar(255)
);

create table cp_stats (
    depo           bigint,
    cp_total       bigint,
    cp_missing     bigint,
    osm_total      bigint,
    osm_linked     bigint,
    osm_linked_pct numeric(6,2),
    cp_timestamp   timestamp with time zone,
    osm_timestamp  timestamp with time zone
);


create table cp_daily_stats (
    day date,
    cp_timestamp   timestamp with time zone,
    osm_timestamp  timestamp with time zone,
    cp_total       bigint,
    cp_missing     bigint,
    osm_total      bigint,
    osm_linked     bigint
);

create table cp_data_state (
    cp timestamp with time zone,
    cp_source varchar(25),
    osm timestamp with time zone,
    stats timestamp with time zone
);

comment on table cp_data_state is 'Info about latest data refresh';
comment on column cp_data_state.cp is 'Czech post boxes';
comment on column cp_data_state.cp_source is 'Czech post source file';
comment on column cp_data_state.osm is 'OSM import';

create table cp_geocoded_coors (
    ref     varchar(25)  NOT NULL,
    lat     numeric(20,10),
    lon     numeric(20,10)
);

grant select on cp_post_boxes to Public;
grant select on osm_post_boxes to Public;
grant select on cp_depos to Public;
grant select on cp_stats to Public;
grant select on cp_daily_stats to Public;
grant select on cp_data_state to Public;
grant select on cp_geocoded_coors to Public;



-- cat POST_SCHRANKY_201802.csv |cut -d ";" -f 1,2 |iconv -f cp1250 -t utf-8 |sort -u| sed "s/\([^;]*\);\(.*\)/insert into cp_depos values (\1, '\2');/" >cp_depos.sql
