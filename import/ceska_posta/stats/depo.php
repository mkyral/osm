<?php
require("config.php");

$id=0;
if (isset($_REQUEST['id'])) $id=$_REQUEST['id'];
if ( !is_numeric($id) ) die;

$query = "
select cp_total,
       cp_missing, (cp_missing::float*100/cp_total::float)::numeric(6,2) cp_missing_pct,
       osm_linked, (osm_linked::float*100/cp_total::float)::numeric(6,2) osm_linked_pct
from ( select
        (select count(1) from cp_post_boxes cp where psc = $id) cp_total,
        (select count(1) from cp_post_boxes cp where psc = $id and x IS NULL) cp_missing,
        (select count(1) from cp_post_boxes cp, post_boxes pb where cp.psc = $id and cp.ref = pb.ref) osm_linked) t";

$result = pg_query($CONNECT,$query);
if (pg_num_rows($result) != 1) die;

$cp_total = pg_result($result,0,"cp_total");
$cp_missing = pg_result($result,0,"cp_missing");
$cp_missing_pct = pg_result($result,0,"cp_missing_pct");

$osm_linked = pg_result($result,0,"osm_linked");
$osm_linked_pct = pg_result($result,0,"osm_linked_pct");

echo("<html>\n");
echo("<head>\n");
echo("<meta charset='utf-8'>");
echo("<title>Import poštovních schránek</title>\n");
echo("<style type='text/css'>\n");
echo("  table.ex1 {border-spacing: 0}\n");
echo("  table.ex1 td, th {padding: 0 0.2em; border-bottom:1pt solid black; padding: 0.5em;}\n");
echo("  table.ex1 tr:nth-child(odd) {color: #000; background: #FFF}\n");
echo("  table.ex1 tr:nth-child(even) {color: #000; background: #CCC}\n");
echo("</style>\n");
echo("</head>\n");
echo("<body style='background: #fff; color: #000'>\n");
echo("<div align=center>\n");
echo("<font size=7><b><a href='.'>Import poštovních schránek</a></b></font><hr>\n");
echo("<img src='image-big.php?p=$osm_linked_pct&q=0.00'><br>\n");
echo("<table style='font-size: 150%; font-weight: bold'><br>\n");
echo("<tr><td>Schránek: </td><td>$cp_total</td></tr>\n");
echo("<tr><td>V OSM: </td><td>$osm_linked</td></tr>\n");
echo("</table><br>\n");
echo("<font size=6><b>Nahráno $osm_linked_pct procent schránek.</b></font><br><hr>\n");

// echo("<font size=5><b>(".number_format($osm_linked,0,".",".")." z ".number_format($cp_total,0,".",".").")</b></font><hr>\n");


$query="select psc, name from cp_depos where psc = $id";

$result=pg_query($CONNECT,$query);
if (pg_num_rows($result) < 1) die;

echo("<br><font size=6><b>Depo: ".$psc." ".$name."</b></font><br><br>\n");


$query="
select cp.ref, cp.psc, cp.id, cp.x, cp.y, cp.lat, cp.lon,
       coalesce(cp.address, cp.suburb||', '||cp.village||', '||cp.district) address,
       cp.place, cp.collection_times, cp.last_update, cp.source,
       pb.latitude, pb.longitude, pb.ref, pb.operator, pb.collection_times
from cp_post_boxes cp
     LEFT OUTER JOIN post_boxes pb
     ON cp.ref = pb.ref
where psc = ".$id."
order by id";

$result=pg_query($CONNECT,$query);
if (pg_num_rows($result) < 1) die;

echo("<table cellpadding=2 border=0 class='ex1'>\n");
echo("<tr><td><b>Ref</b></td>
      <td><b>Umístění<br>Popis</b></td>
      <td><b>Výběr</b>
      </td><td><b>Křovák<br>WGS84</b>
      </td><td><b></b>
      </td><td><b>Zdroj</b></td>
      <td></td></tr>\n");
for ($i=0;$i<pg_num_rows($result);$i++)
{
    $krovak = '';
    $latlon = '';
    if (pg_result($result,$i,"x") != '') {
        $krovak = (float)pg_result($result,$i,"x").", ".(float)pg_result($result,$i,"y");
    }
    if (pg_result($result,$i,"lat") != '') {
        $latlon = (float)pg_result($result,$i,"lat").", ".(float)pg_result($result,$i,"lon");
    }

    echo("<tr>\n");
    echo("<td>".pg_result($result,$i,"ref")."</a></td>\n");
    echo("<td>".pg_result($result,$i,"address")."<br>".pg_result($result,$i,"place")."</td>\n");
    echo("<td>".pg_result($result,$i,"collection_times")."</td>\n");
    echo("<td>".$krovak."<br>".$latlon."</td>\n");
    echo("<td>".pg_result($result,$i,"source")."</td>\n");
    echo("<td></td>\n");
    echo("</tr>\n");
}
echo("</table>\n");

echo("</div>\n");
echo("</body>\n");
echo("</html>\n");
?>
