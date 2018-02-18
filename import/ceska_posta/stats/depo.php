<?php
require("config.php");

$id=0;
if (isset($_REQUEST['id'])) $id=$_REQUEST['id'];
if ( !is_numeric($id) ) die;

$filters = array(
    "OK" => "OK",
    "Partial" => "Částečně",
    "Missing" => "Chybí",
    "Deleted" => "Zrušeno"
);

$filter = '';
if (isset($_REQUEST['filter'])) $filter = $_REQUEST['filter'];
if (!array_key_exists($filter, $filters)) $filter = '';

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

echo("<html>\n");
echo("<head>\n");
echo("  <meta charset='utf-8'>");
echo("  <title>Import poštovních schránek</title>\n");
echo("  <link rel='stylesheet' href='style.css'/>");
echo("</head>\n");
echo("<body style='background: #fff; color: #000'>\n");
echo("<div align=center>\n");
echo("<font size=7><b><a href='.'>Import poštovních schránek</a></b></font><hr>\n");
echo("<br><font size=6><b>".$depo." ".$depo_name."</b></font><br><br>\n");
echo("<img src='image-big.php?p=$osm_linked_pct&q=0.00'><br>\n");
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


$query="
select cp.ref, cp.psc, cp.id, cp.x, cp.y, cp.lat, cp.lon,
       coalesce(cp.address, cp.suburb||', '||cp.village||', '||cp.district) address,
       cp.place, cp.collection_times cp_collection_times, cp.last_update, cp.source,
       pb.id osm_id, pb.latitude, pb.longitude, pb.ref, pb.operator,
       pb.collection_times osm_collection_times, pb.fixme,
       CASE WHEN pb.id IS NOT NULL and cp.state = 'D' THEN 'Deleted'
            WHEN pb.id IS NULL and cp.state = 'A' THEN 'Missing'
            WHEN pb.id IS NOT NULL and
                 cp.state = 'A' and
                 cp.collection_times = pb.collection_times and
                 coalesce(pb.operator, 'xxx') = 'Česká pošta, s.p.' and
                 pb.fixme IS NULL THEN 'OK'
            WHEN pb.id IS NOT NULL and cp.state = 'A' THEN 'Partial'
            ELSE 'Deleted'
       END as state
from cp_post_boxes cp
     LEFT OUTER JOIN osm_post_boxes pb
     ON cp.ref = pb.ref
where psc = ".$id."
order by cp.id";

$result=pg_query($CONNECT,$query);
if (pg_num_rows($result) < 1) die;

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

echo("</div>");

echo("<table cellpadding=2 border=0 class='ex1'>\n");
echo("<tr>
        <td></td>
        <td><b>Ref<br><br>OSM Id</b></td>
        <td><b>Umístění<br>Popis</b></td>
        <td><b>Výběr</b></td>
        <td><b>Křovák<br>WGS84<br>OSM</b></td>
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

    $krovak = '';
    $latlon = '';
    $osm_latlon = '';
    $ref_url = pg_result($result,$i,"ref");
    $poi_url = '';

    if (pg_result($result,$i,"x") != '') {
        $krovak = (float)pg_result($result,$i,"x").", ".(float)pg_result($result,$i,"y");
    }
    if (pg_result($result,$i,"lat") != '') {
        $latlon = (float)pg_result($result,$i,"lat").", ".(float)pg_result($result,$i,"lon");
        $ref_url = "<a href='http://osm.kyralovi.cz/POI-Importer-testing/#map=17/".((float)pg_result($result,$i,"lat"))."/".((float)pg_result($result,$i,"lon"))."&datasets=CZECPbox' title='Přejít na POI-Importer'>".pg_result($result,$i,"ref")."</a>";
    }
    if (pg_result($result,$i,"latitude") != '') {
        $osm_latlon = (((float)pg_result($result,$i,"latitude"))/10000000).", ".(((float)pg_result($result,$i,"longitude"))/10000000);
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
            if (pg_result($result,$i,"operator") == '') {
                $msg[] = "<span class='label partial lower smaller'>Chybí operátor</span>";
            }
            elseif (pg_result($result,$i,"operator") != 'Česká pošta, s.p.') {
                $msg[] = "<span class='label partial lower smaller'>Nesprávný operátor: ".pg_result($result,$i,"operator")."</span>";
            }
            if (pg_result($result,$i,"fixme") != '') {
                $msg[] = "<span class='label partial lower smaller' title='".pg_result($result,$i,"fixme")."'>Fixme</span>";
            }
            break;
     case 'Deleted':
            $stc = "<span class='label deleted'>Zrušeno</span>";
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
    echo("<td>".$krovak."<br>".$latlon."<br>".$osm_latlon."</td>\n");
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
