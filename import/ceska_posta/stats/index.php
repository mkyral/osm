<?php
require("config.php");

$query = "select cp_total,
       cp_missing, (cp_missing::float*100/cp_total::float)::numeric(6,2) cp_missing_pct,
       osm_total,
       osm_linked, (osm_linked::float*100/cp_total::float)::numeric(6,2) osm_linked_pct,
       (osm_total-osm_linked) osm_not_linked, ((osm_total-osm_linked)::float*100/cp_total::float)::numeric(6,2) osm_not_linked_pct
from cp_stats where depo = 0";

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
echo("  <title>Import poštovních schránek</title>\n");
echo("  <link rel='stylesheet' href='style.css'/>");
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
       cp_missing, CASE WHEN cp_missing_pct > 100 THEN 100 ELSE cp_missing_pct END cp_missing_pct,
       osm_linked, CASE WHEN osm_linked_pct > 100 THEN 100 ELSE osm_linked_pct END osm_linked_pct,
       diff_to_prev
from ( select psc, name, cp_total,
              cp_missing, CASE cp_total WHEN 0 THEN 0 ELSE (cp_missing::float*100/cp_total::float)::numeric(6,2) END cp_missing_pct,
              osm_linked, CASE cp_total WHEN 0 THEN 0 ELSE (osm_linked::float*100/cp_total::float)::numeric(6,2) END osm_linked_pct,
              (osm_linked - prev_osm_linked) diff_to_prev
       from ( select d.psc, d.name,
              s.cp_total, s,cp_missing, s.osm_linked, s.prev_osm_linked
             from cp_depos d, cp_stats s
             where d.psc = s.depo) x) al
order by psc";

$result=pg_query($CONNECT,$query);
if (pg_num_rows($result) < 1) die;

echo("<br><font size=6><b>Depa</b></font><br><br>\n");
echo("<table cellpadding=2 border=0>\n");
echo("<tr><td><b>Depo</b></td><td><b>Schránek</b></td><td><b>Nahráno</b></td><td><b>Procent</b></td><td><b>Bez souřadnic</b></td><td><b>Procent</b></td><td></td></tr>\n");
for ($i=0;$i<pg_num_rows($result);$i++)
{
    $empty=(pg_result($result,$i,"cp_total") > 0) ? "" : " class='empty'";
    echo("<tr".$empty.">\n");
    if (pg_result($result,$i,"cp_total") > 0) {
        echo("<td><a href='depo.php?id=".pg_result($result,$i,"psc")."'>".pg_result($result,$i,"psc")." ".pg_result($result,$i,"name")."</a></td>\n");
    } else {
        echo("<td>".pg_result($result,$i,"psc")." ".pg_result($result,$i,"name")."</td>\n");
    }
    echo("<td>".pg_result($result,$i,"cp_total")."</td>\n");
    echo("<td>".pg_result($result,$i,"osm_linked"));

    if (pg_result($result,$i,"diff_to_prev") > 0) {
        echo (" <span class='statsdiff'>(+".pg_result($result,$i,"diff_to_prev").")</span>");
    } elseif (pg_result($result,$i,"diff_to_prev") < 0) {
        echo (" <span class='statsdiff'>(".pg_result($result,$i,"diff_to_prev").")</span>");
    }
    echo("</td>\n");

    echo("<td>".pg_result($result,$i,"osm_linked_pct")."</td>\n");
    echo("<td>".pg_result($result,$i,"cp_missing")."</td>\n");
    echo("<td>".pg_result($result,$i,"cp_missing_pct")."</td>\n");
    echo("<td><img src='image.php?p=".((pg_result($result,$i,"osm_linked_pct") > 0) ? pg_result($result,$i,"osm_linked_pct") : 100)."&q=0.00'></td>\n");
    echo("</tr>\n");
}
echo("</table>\n");

$query = "
select to_char(cp, 'DD.MM.YYYY') as cp, cp_source, to_char(osm, 'DD.MM.YYYY') as osm,
       to_char(stats, 'DD.MM.YYYY HH24:MI:SS') as stats
from cp_data_state";

$result = pg_query($CONNECT,$query);
if (pg_num_rows($result) != 1) die;

$state_cp = pg_result($result,0,"cp");
$state_cp_source = pg_result($result,0,"cp_source");
$state_osm = pg_result($result,0,"osm");
$state_stats = pg_result($result,0,"stats");

echo("
<br>
<b>Statistiky jsou přepočítávány jednou denně.</b><br>
<br>
<b>Poslední přepočet:</b> $state_stats, <br><br>
<b>Data ke dni:</b> Česká pošta - ".$state_cp." (".$state_cp_source.") | Openstreetmap - ".$state_osm."<br><br>\n");

echo("</div>\n");
echo("</body>\n");
echo("</html>\n");
?>
