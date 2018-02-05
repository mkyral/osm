create table post_boxes (
    id               bigint,
    latitude         numeric(20,4),
    longitude        numeric(20,4),
    ref              character varying(255),
    operator         character varying(255),
    collection_times character varying(255),
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
    address varchar(255),
    place varchar(255),
    suburb varchar(255),
    village varchar(255),
    district varchar(255),
    collection_times varchar(255),
    create_date timestamp,
    last_update timestamp,
    source varchar(255)
);

create table cp_depos (
    psc numeric(10),
    name varchar(255)
);

grant select on cp_post_boxes to guest;
grant select on post_boxes to guest;
grant select on cp_depos to guest;


-- cat POST_SCHRANKY_201802.csv |cut -d ";" -f 1,2 |iconv -f cp1250 -t utf-8 |sort -u| sed "s/\([^;]*\);\(.*\)/insert into cp_depos values (\1, '\2');/" >cp_depos.sql
