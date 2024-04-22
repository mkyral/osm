<?php

global $CONNECT,$RESULT,$DBDATABASE,$DBUSER,$DBPASSWORD;

$DBHOST = "localhost";
$DBDATABASE = "pedro";
$DBUSER = "guest";
$DBPASSWORD = "guest";
$CONNECT = pg_connect("host=$DBHOST dbname=$DBDATABASE password=$DBPASSWORD user=$DBUSER")
 or die("Databaze je down.");
$set = pg_query($CONNECT,"set search_path to marian,ruian,osmtables,public;");
?>
