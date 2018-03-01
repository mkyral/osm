<?php
/*
 * login_with_bitbucket.php
 *
 * @(#) $Id: login_with_bitbucket.php,v 1.2 2013/07/31 11:48:04 mlemos Exp $
 *
 */

	/*
	 *  Get the http.php file from http://www.phpclasses.org/httpclient
	 */
    if (!isset($oauth_id)) {
        require("config.php");
    }

    $oauth_debug = false;

	$client = new oauth_client_class;
	$client->debug = false;
	$client->debug_http = true;
	$client->server = 'OpenStreetMap.org';
	$client->redirect_uri = 'http://'.$_SERVER['HTTP_HOST'].
		dirname(strtok($_SERVER['REQUEST_URI'],'?')).'/login_with_osm.php';

	$client->client_id = $oauth_id; $application_line = __LINE__;
	$client->client_secret = $oauth_secret;

	if(strlen($client->client_id) == 0
	|| strlen($client->client_secret) == 0)
		die('Please go to Bitbucket page to Manage Account '.
			'https://https://www.openstreetmap.org/ , click on My setting/oauth, '.
			'then Add Consumer, and in the line '.$application_line.
			' set the client_id with Key and client_secret with Secret. '.
			'The URL must be '.$client->redirect_uri);

	if(($success = $client->Initialize()))
	{
		if(($success = $client->Process()))
		{
			if(strlen($client->access_token))
			{
				$success = $client->CallAPI(
					'https://api.openstreetmap.org/api/0.6/user/details',
					'GET', array(), array('FailOnAccessError'=>true), $reply);
					$parse = new SimpleXMLElement($reply);
					$user = array(
                        "id" => HtmlSpecialChars((string) $parse->user['id']),
                        "name" => HtmlSpecialChars((string) $parse->user['display_name']),
                        "avatar" => HtmlSpecialChars((string) $parse->user->img['href']));
			}
		}
		$success = $client->Finalize($success);
	}
	if($client->exit)
		exit;
	if($success)
	{
        if($oauth_debug == true) {
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>OpenStreetMap.org OAuth client results</title>
</head>
<body>
<?php

		echo '<h1>', $user['name'], ' (', $user['id'] ,') <img src="', $user['avatar'], '" width="25px"/>',
			', you have logged in successfully with OpenStreetMap.org!</h1>';
        echo '<pre>', HtmlSpecialChars(print_r($user, 1)), '</pre>';
        echo '<hr> <hr>';
        foreach($parse->user[0]->img->attributes() as $a => $b) {
            echo $a,'="',$b,"\"<br>\n";
        }
        echo '<hr> <hr>';
		echo '<pre>', HtmlSpecialChars(print_r($parse, 1)), '</pre>';
?>
</body>
</html>
<?php
        }
	}
	else
	{
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<title>OAuth client error</title>
</head>
<body>
<h1>OAuth client error</h1>
<pre>Error: <?php echo HtmlSpecialChars($client->error); ?></pre>
</body>
</html>
<?php
	}

?>
