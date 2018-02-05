<?php
ini_set('default_charset','iso8859-2');
global $CONNECT,$RESULT,$DBDATABASE,$DBUSER,$DBPASSWORD;

$DBHOST = "localhost";
$DBDATABASE = "pedro";
$DBUSER = "guest";
$DBPASSWORD = "guest";
$CONNECT = pg_connect("host=$DBHOST dbname=$DBDATABASE password=$DBPASSWORD user=$DBUSER")
 or die("Databaze je down.");
$set = pg_query($CONNECT,"set client_encoding to latin2;");

$id=0;
if (isset($_REQUEST['id'])) $id=$_REQUEST['id'];
if ( !is_numeric($id) ) die;
$query = "select *,round(importovano/celkem*100,2) as procent,round(zpracovavano/celkem*100,2) as zpracovavanoprocent from
    (select sum(celkem) as celkem,sum(importovano) as importovano,sum(zpracovavano) as zpracovavano from import.stat_all) as foo";
$result=pg_query($CONNECT,$query);
if (pg_num_rows($result) != 1) die;
$celkem=pg_result($result,0,"celkem");
$importovano=pg_result($result,0,"importovano");
$procent=pg_result($result,0,"procent");
$zpracovavano=pg_result($result,0,"zpracovavano");
$zpracovavanoprocent=pg_result($result,0,"zpracovavanoprocent");
echo("\n");
echo("<html>\n");
echo("<div align=center>\n");
echo("<font size=7><b><a href=\".\">Import adres z RÚIAN</a></b></font><hr>\n");
if ( $procent > 99.99 )
    {
	echo("<img src=\"ghost-final.png\" align=\"top\" vspace=\"5px\"><br>\n");
    }
    else
    {
	echo("<img src=\"image-big.php?p=".$procent."&q=".$zpracovavanoprocent."\"><br>\n");
    }
echo("<font size=6><b>Nahráno ".$procent." procent adres.</b></font><br>\n");
echo("<font size=5><b>(".number_format($importovano,0,".",".")." z ".number_format($celkem,0,".",".").")</b></font><hr>\n");
?>
