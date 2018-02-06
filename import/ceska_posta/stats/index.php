<?php
require("config.php");

$query = "select cp_total,
       cp_missing, (cp_missing::float*100/cp_total::float)::numeric(6,2) cp_missing_pct,
       osm_total,
       osm_linked, (osm_linked::float*100/cp_total::float)::numeric(6,2) osm_linked_pct,       (osm_total-osm_linked) osm_not_linked, ((osm_total-osm_linked)::float*100/cp_total::float)::numeric(6,2) osm_not_linked_pct
from ( select
        (select count(1) from cp_post_boxes cp ) cp_total,
        (select count(1) from cp_post_boxes cp where x IS NULL) cp_missing,
        (select count(1) from post_boxes pb) osm_total,
        (select count(1) from cp_post_boxes cp, post_boxes pb where cp.ref = pb.ref) osm_linked) t";

$result = pg_query($CONNECT,$query);
if (pg_num_rows($result) != 1) die;

$cp_total = pg_result($result,0,"cp_total");
$cp_missing = pg_result($result,0,"cp_missing");
$cp_missing_pct = pg_result($result,0,"cp_missing_pct");

$osm_total = pg_result($result,0,"osm_total");

$osm_linked = pg_result($result,0,"osm_linked");
$osm_linked_pct = pg_result($result,0,"osm_linked_pct");

$osm_not_linked = pg_result($result,0,"osm_not_linked");
$osm_not_linked_pct = pg_result($result,0,"osm_not_linked_pct");


echo("<html>\n");
echo("<head>\n");
echo("<meta charset='utf-8'>");
echo("<title>Import poštovních schránek</title>\n");
echo("</head>\n");
echo("<body style='background: #fff; color: #000'>\n");
echo("<div align=center>\n");
echo("<font size=7><b><a href='.'>Import poštovních schránek</a></b></font><hr>\n");
echo("<img src='image-big.php?p=".$osm_linked_pct."&q=".$osm_not_linked_pct."'><br>\n");
echo("<table style='font-size: 150%; font-weight: bold'><br>\n");
echo("<tr><td>Schránek celkem: </td><td>".$cp_total."</td></tr>\n");
echo("<tr><td>Schránek v OSM: </td><td>".$osm_total."</td></tr>\n");
echo("<tr><td>Schránek propojeno: </td><td>".$osm_linked."</td></tr>\n");
echo("</table><br>\n");
echo("<font size=6><b>Nahráno ".$osm_linked_pct." procent schránek.</b></font><br><hr>\n");

// echo("<font size=5><b>(".number_format($osm_linked,0,".",".")." z ".number_format($cp_total,0,".",".").")</b></font><hr>\n");


$query="
select psc, name, cp_total,
       cp_missing, (cp_missing::float*100/cp_total::float)::numeric(6,2) cp_missing_pct,
       osm_linked, (osm_linked::float*100/cp_total::float)::numeric(6,2) osm_linked_pct
from ( select d.psc, d.name,
        (select count(1) from cp_post_boxes cp where cp.psc = d.psc) cp_total,
        (select count(1) from cp_post_boxes cp where cp.psc = d.psc and x IS NULL) cp_missing,
        (select count(1) from cp_post_boxes cp, post_boxes pb where cp.psc = d.psc and cp.ref = pb.ref) osm_linked
      from cp_depos d) s";

$result=pg_query($CONNECT,$query);
if (pg_num_rows($result) < 1) die;

echo("<br><font size=6><b>Depa</b></font><br><br>\n");
echo("<table cellpadding=2 border=0>\n");
echo("<tr><td><b>Depo</b></td><td><b>Schránek</b></td><td><b>Nahráno</b></td><td><b>Procent</b></td><td><b>Bez souřadnic</b></td><td><b>Procent</b></td><td></td></tr>\n");
for ($i=0;$i<pg_num_rows($result);$i++)
    {
    echo("<tr>\n");
    echo("<td><a href='depo.php?id=".pg_result($result,$i,"psc")."'>".pg_result($result,$i,"psc")." ".pg_result($result,$i,"name")."</a></td>\n");
    echo("<td>".pg_result($result,$i,"cp_total")."</td>\n");
    echo("<td>".pg_result($result,$i,"osm_linked")."</td>\n");
    echo("<td>".pg_result($result,$i,"osm_linked_pct")."</td>\n");
    echo("<td>".pg_result($result,$i,"cp_missing")."</td>\n");
    echo("<td>".pg_result($result,$i,"cp_missing_pct")."</td>\n");
    echo("<td><img src='image.php?p=".pg_result($result,$i,"osm_linked_pct")."&q=0.00'></td>\n");
    echo("</tr>\n");
    }
echo("</table>\n");

echo("</div>\n");
echo("</body>\n");
echo("</html>\n");
?>