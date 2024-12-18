<?php
require("config.php");

$id=0;
if (isset($_REQUEST['id'])) $id=$_REQUEST['id'];
if ( !is_numeric($id) ) die;

$filters = array(
    "OK" => "OK",
    "Partial" => "Částečně",
    "Missing" => "Chybí",
    "Deleted" => "Zrušeno",
    "Inactive" => "Neaktivní"
);

$filter = '';
if (isset($_REQUEST['filter'])) $filter = $_REQUEST['filter'];
if (!array_key_exists($filter, $filters)) $filter = '';

$export = '';
if (isset($_REQUEST['export'])) $export = $_REQUEST['export'];
if ($export != 'gpx') $export = '';


$query = "
select cp_total,
       cp_missing, (cp_missing::float*100/cp_total::float)::numeric(6,2) cp_missing_pct,
       osm_linked, (osm_linked::float*100/cp_total::float)::numeric(6,2) osm_linked_pct
from ( select
        (select count(1) from cp_post_boxes cp where psc = $id and state = 'A') cp_total,
        (select count(1) from cp_post_boxes cp where psc = $id and x IS NULL and state = 'A') cp_missing,
        (select count(1) from cp_post_boxes cp, osm_post_boxes pb where cp.psc = $id and cp.ref = pb.ref) osm_linked) t";

$result = pg_query($CONNECT,$query);
if (pg_num_rows($result) != 1) die;

$cp_total = pg_result($result,0,"cp_total");
$cp_missing = pg_result($result,0,"cp_missing");
$cp_missing_pct = pg_result($result,0,"cp_missing_pct");

$osm_linked = pg_result($result,0,"osm_linked");
$osm_linked_pct = pg_result($result,0,"osm_linked_pct");

$query="select psc, name from cp_depos where psc = $id";

$result=pg_query($CONNECT,$query);
if (pg_num_rows($result) < 1) die;

$depo=pg_result($result,0,"psc");
$depo_name=pg_result($result,0,"name");

if ($export == '') {
    echo("<html>\n");
    echo("<head>\n");
    echo("  <meta charset='utf-8'>");
    echo("  <title>Import poštovních schránek</title>\n");
    echo("  <link rel='stylesheet' href='style.css'/>");
    echo("</head>\n");
    echo("<body style='background: #fff; color: #000'>\n");
    echo("<div id='userbox'>".$user_text."</div><br>\n");
    echo("<div align=center>\n");
    echo("<font size=7><b><a href='.'>Import poštovních schránek</a></b></font><hr>\n");
    echo("<br><font size=6><b>".$depo." ".$depo_name."</b></font><br><br>\n");
    echo("<img src='graph.php?t=big&p=$osm_linked_pct&q=0.00'><br>\n");
    echo("<table style='font-size: 150%; font-weight: bold'><br>\n");
    echo("<tr><td>Schránek: </td><td>$cp_total</td></tr>\n");
    echo("<tr><td>V OSM: </td><td>$osm_linked</td></tr>\n");
    echo("</table><br>\n");
    echo("<font size=6><b>Nahráno $osm_linked_pct procent schránek.</b></font><br><hr>\n");


    echo("
    <div id='myModal' class='modal'>

    <!-- Modal content -->
    <div class='modal-content'>
        <span class='close'>&times;</span>
        <h1 id='myModalHeader'>Header</h1>
        <p id='myModalContent'>Some text in the Modal..</p>
    </div>

    </div>
    ");
}

$query="
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
where psc = ".$id."
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
            WHEN osm_id IS NOT NULL and state = 'I' THEN 'Inactive'
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
from depo_data";

$result=pg_query($CONNECT,$query);
if (pg_num_rows($result) < 1) die;

if ($export == 'gpx') {
    header("Content-Type: application/gpx+xml");
    header("Content-Disposition: attachment; filename=cpost_".$id."_".$filter.".gpx");

    echo '<?xml version="1.0" encoding="utf-8" standalone="yes"?>'."\n";
    echo '<gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.1" creator="poloha.net http://josm.poloha.net/cz_pbox" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd   http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensions/v3/GpxExtensionsv3.xsd">'."\n";

    for ($i=0;$i<pg_num_rows($result);$i++)
    {
        if (pg_result($result,$i,"state") == 'Deleted' and pg_result($result,$i,"osm_id") == '') {
            # Post box no more exists and is not in OSM - skip it
            continue;
        }

        if ( !empty($filter) and pg_result($result,$i,"state") != $filter) {
            continue;
        }

        $lat = '';
        $lon = '';

        if (pg_result($result,$i,"osm_lat") != '' ) {
            $lat = (float)pg_result($result,$i,"osm_lat");
            $lon = (float)pg_result($result,$i,"osm_lon");
        } else {
            $lat = (float)pg_result($result,$i,"lat");
            $lon = (float)pg_result($result,$i,"lon");
        }

        echo '<wpt lat="'.$lat.'" lon="'.$lon.'">'."\n";
        echo '  <name>'.pg_result($result,$i,"ref").'</name>'."\n";
        echo '  <desc>'.pg_result($result,$i,"address")." \n ".pg_result($result,$i,"place").'</desc>'."\n";
        echo '  <extensions><gpxx:WaypointExtension><gpxx:Proximity>100</gpxx:Proximity></gpxx:WaypointExtension></extensions>'."\n";
        echo '</wpt>'."\n";
    }

    echo '</gpx>'."\n";


    exit;
}

# Labels row
echo("<div class='labels'>");
if (empty($filter)) {
    echo("<span class='label normal active'><b>Vše</b></span> \n");
} else {
    echo("<a href='depo.php?id=$id'><span class='label normal'>Vše</span></a> \n");
}

foreach($filters as $ft => $ft_val) {
    if ($filter == $ft) {
        echo("<span class='label ".strtolower($ft)." active'><b>".$ft_val."</b></span> \n");
    } else {
        echo("<a href='depo.php?id=$id&filter=$ft'><span class='label ".strtolower($ft)."'>".$ft_val."</span></a> \n");
    }
}

echo("<a href='depo.php?id=$id&filter=$filter&export=gpx'><span class='label save right'>&#x1f4be; gpx</span></a> \n");

echo("</div>");

echo("<table cellpadding=2 border=0 class='ex1 mt-5'>\n");
echo("<tr class='tbl-header'>
        <td></td>
        <td><b>Ref<br><br>OSM Id</b></td>
        <td><b>Umístění<br>Popis</b></td>
        <td><b>Výběr</b></td>
        <td><b>Pošta<br>OSM<br>Vzdálenost</b></td>
        <td><b>Zdroj</b></td>
      </tr>\n");
for ($i=0;$i<pg_num_rows($result);$i++)
{
    if (pg_result($result,$i,"state") == 'Deleted' and pg_result($result,$i,"osm_id") == '') {
        # Post box no more exists and is not in OSM - skip it
        continue;
    }

    if ( !empty($filter) and pg_result($result,$i,"state") != $filter) {
        continue;
    }

    $distance = '';
    $latlon = '';
    $osm_latlon = '';
    $ref_url = pg_result($result,$i,"ref");
    $poi_url = '';

    if (pg_result($result,$i,"distance") != '') {
        if (pg_result($result,$i,"distance") > 250) {
            $distance = "<span class='warning'>".pg_result($result,$i,"distance_formated")."</span>";
        } else{
            $distance = pg_result($result,$i,"distance_formated");
        }
    }
    if (pg_result($result,$i,"lat") != '') {
        $latlon = "<a href='https://osm.org/?mlat=".((float)pg_result($result,$i,"lat"))."&mlon=".((float)pg_result($result,$i,"lon"))."&zoom=17' title='Přejít na osm.org'>".((float)pg_result($result,$i,"lat")).", ".((float)pg_result($result,$i,"lon"))."</a>";

        $ref_url = "<a href='https://openstreetmap.cz/poi-importer/#map=17/".((float)pg_result($result,$i,"lat"))."/".((float)pg_result($result,$i,"lon"))."&datasets=CZECPbox' title='Přejít na POI-Importer'>".pg_result($result,$i,"ref")."</a>";
    }
    if (pg_result($result,$i,"osm_lat") != '') {
        $osm_latlon = "<a href='https://osm.org/?mlat=".((float)pg_result($result,$i,"osm_lat"))."&mlon=".((float)pg_result($result,$i,"osm_lon"))."&zoom=17' title='Přejít na osm.org'>".((float)pg_result($result,$i,"osm_lat")).", ".((float)pg_result($result,$i,"osm_lon"))."</a>";

        $poi_url = "<a href='https://osm.org/node/".pg_result($result,$i,"osm_id")."' title='Přejít na osm.org'>".pg_result($result,$i,"osm_id")."</a>";
    }

    $msg = array();
    switch (pg_result($result,$i,"state")) {
     case 'OK':
            $stc = "<span class='label ok'>OK</span>";
            break;
     case 'Partial':
            $stc = "<span class='label partial'>Částečně</span>";
            if (pg_result($result,$i,"cp_collection_times") != pg_result($result,$i,"osm_collection_times")) {
                $msg[] = "<span class='label partial lower smaller'>Nesouhlasí časy výběru</span>";
            }
            if (pg_result($result,$i,"osm_operator") == '') {
                $msg[] = "<span class='label partial lower smaller'>Chybí operátor</span>";
            }
            elseif (pg_result($result,$i,"osm_operator") != 'Česká pošta, s.p.') {
                $msg[] = "<span class='label partial lower smaller'>Nesprávný operátor: ".pg_result($result,$i,"osm_operator")."</span>";
            }
            if (pg_result($result,$i,"osm_fixme") != '') {
                $msg[] = "<span class='label partial lower smaller' title='".pg_result($result,$i,"osm_fixme")."'>Fixme</span>";
            }
            if (pg_result($result,$i,"distance") >= 1000) {
                $msg[] = "<span class='label partial lower smaller' title='Schránka v OSM je podezřele daleko: ".pg_result($result,$i,"distance_formated")."'>Vzdálenost</span>";
            }
            if (pg_result($result,$i,"osm_links_count") > 1) {
                $msg[] = "<span class='label partial lower smaller' title='V OSM je schránka vícekrát: ".pg_result($result,$i,"osm_links_count")."x'>Duplicita</span>";
            }
            break;
     case 'Deleted':
            $stc = "<span class='label deleted'>Zrušeno</span>";
            break;
     case 'Inactive':
            $stc = "<span class='label deleted'>Neaktivní</span>";
            break;
     case 'Missing':
            $stc = "<span class='label missing'>Chybí</span>";
            break;
     default:
            $stc = "";
    }

    echo("<tr>\n");
    echo("<td><br>$stc<br><br></td>\n");
    echo("<td>".$ref_url."<br><br>".$poi_url."</td>\n");
    echo("<td>".pg_result($result,$i,"address")."<br>".pg_result($result,$i,"place")."<br>".implode(" ",$msg)."</td>\n");
    echo("<td>".pg_result($result,$i,"cp_collection_times")."<br><br>".pg_result($result,$i,"osm_collection_times")."</td>\n");
    echo("<td style='text-align: right;'>".$latlon."<br>".$osm_latlon."<br>".$distance."</td>\n");
//     export_tags.php?id=".pg_result($result,$i,"ref")."
    echo("<td>".pg_result($result,$i,"source")."<br>
          <br><img src='img/copy-tags.png' alt='+++'title='Vypsat OSM tagy' onclick='showOsmTags(\"".pg_result($result,$i,"ref")."\",\"".pg_result($result,$i,"cp_collection_times")."\")' class='link'></td>\n");
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
<b>Poslední přepočet:</b> $state_stats <br><br>
<b>Data ke dni:</b> Česká pošta - ".$state_cp." (".$state_cp_source.") | Openstreetmap - ".$state_osm."<br><br>\n");

echo("</div>\n");

echo("
<script>
// Get the modal and content
var modal = document.getElementById('myModal');
var modalContent = document.getElementById('myModalContent');
var modalHeader = document.getElementById('myModalHeader');

// Get the <span> element that closes the modal
var span = document.getElementsByClassName('close')[0];

// When the user clicks the button, open the modal
showOsmTags = function (ref, ct) {
    modal.style.display = 'block';
    modalHeader.innerText=ref;
    modalContent.innerHTML='<pre>amenity=post_box<br>collection_times=' + ct + '<br>operator=Česká pošta, s.p.<br>ref=' + ref + '<br></pre>';
}

// When the user clicks on <span> (x), close the modal
span.onclick = function() {
    modal.style.display = 'none';
}

// When the user clicks anywhere outside of the modal, close it
window.onclick = function(event) {
    if (event.target == modal) {
        modal.style.display = 'none';
    }
}
</script>
");

echo("</body>\n");
echo("</html>\n");
?>
