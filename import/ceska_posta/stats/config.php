<?php
global $CONNECT,$RESULT,$DBDATABASE,$DBUSER,$DBPASSWORD;

require('oauth_config.php');
require('libs/httpclient/http.php');
require('libs/oauth/oauth_client.php');

$DBHOST = "localhost";
$DBDATABASE = "pedro";
$DBUSER = "guest";
$DBPASSWORD = "guest";
$CONNECT = pg_connect("host=$DBHOST dbname=$DBDATABASE password=$DBPASSWORD user=$DBUSER")
 or die("Databaze je down.");
$set = pg_query($CONNECT,"set search_path to marian,ruian,osmtables,public;");

$use_oauth = false;

// Handle action parameter - login or logout
$action = '';
if (isset($_REQUEST['action'])) $action=$_REQUEST['action'];
if ( $action == 'login' ) {
    setcookie('cppbox_oauth', 'yes', time() + (86400 * 30), "/"); // 86400 = 1 day
} elseif ($action == 'logout') {
    setcookie("cppbox_oauth", "", time() - 3600, "/");
} else {
  $action = '';
}

if ( $action == 'login' or
    ($action != 'logout' and isset($_COOKIE['cppbox_oauth']) and $_COOKIE['cppbox_oauth'] == 'yes')
   ) {
    // OAuth
    require("login_with_osm.php");
}

// Prepare user string
if ($_SERVER['QUERY_STRING']) {
    $query="&".$_SERVER['QUERY_STRING'];
} else {
    $query='';
}

if (!isset($user)) {
    $user_text='<b>Uživatel:</b> nepřihlášen (<a href="'.$_SERVER['PHP_SELF'].'?action=login'.$query.'">Přihlásit</a> - osm.org)';
} else {
    $user_text='<b>Uživatel:</b> '.$user['name'].' <img src="'.$user['avatar'].'" class="avatar" height="25px"/> (<a href="'.$_SERVER['PHP_SELF'].'?action=logout'.$query.'">odhlásit</a>)';
}

?>
