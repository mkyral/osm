<?php

require_once ('jpgraph/jpgraph.php');
require_once ('jpgraph/jpgraph_bar.php');
$p=0;
$q=0;
if (isset($_REQUEST['p'])) $p=$_REQUEST['p'];
if (isset($_REQUEST['q'])) $q=$_REQUEST['q'];
if ( ! is_numeric($p) || ! is_numeric($q) ) die;
$p = (int) $p;
$q = (int) $q;

$data1y=array($p); // hotovo
$data2y=array($q); // zpracovava se
$data3y=array(100-$p-$q); // zbyva

$graph = new Graph(200,18);
$graph->SetAngle(90);
$graph->SetScale("textlin");

$graph->img->SetMargin(00,00,-91,-91);

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
