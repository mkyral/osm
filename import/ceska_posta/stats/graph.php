<?php

require_once ('libs/jpgraph/jpgraph.php');
require_once ('libs/jpgraph/jpgraph_bar.php');
$p=0;
$q=0;
$t='';
if (isset($_REQUEST['p'])) $p=$_REQUEST['p'];
if (isset($_REQUEST['q'])) $q=$_REQUEST['q'];
if (isset($_REQUEST['t'])) $t=$_REQUEST['t'];
if ( ! is_numeric($p) || ! is_numeric($q) ) die;
$p = (int) $p;
$q = (int) $q;
if ($t == 'big') {
    $w =   600;
    $h =    80;
    $m =  -260;
} else {
    $w =  200;
    $h =   18;
    $m =  -91;
}

$data1y=array($p); // hotovo
$data2y=array($q); // zpracovava se
$data3y=array(100-$p-$q); // zbyva

$graph = new Graph((int) $w, (int) $h);
$graph->SetAngle(90);
$graph->SetScale("textlin");

$graph->img->SetMargin(00,00,(int)$m,(int)$m);

//$graph->yaxis->SetPos('max');
//$graph->yaxis->SetPos(600);
$graph->graph_theme = null;


$b1plot = new BarPlot($data1y);
$b1plot->SetFillColor("#ffcd33");
$b2plot = new BarPlot($data2y);
$b2plot->SetFillColor("#ffdc00");
$b3plot = new BarPlot($data3y);
$b3plot->SetFillColor("#13377d");
$abplot = new AccBarPlot(array($b1plot,$b2plot,$b3plot));
//$abplot->SetShadow();
$graph->Add($abplot);
//$graph->StrokeCSIM();
$graph->Stroke();

?>
