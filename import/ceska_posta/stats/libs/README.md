# stats/libs

Používané knihovny

## Instalace

1) Vytvořte složky níže a nakopírujte tam obsah stažených archívů:
(složka musí obsahovat soubory ze `src` adresáře nebo na ně musí ukazovat)

|Složka      | web adresa                                                                           |
|------------|--------------------------------------------------------------------------------------|
|httpclient  |http://www.phpclasses.org/httpclient                                                  |
|jpgraph     |symbolický link na jpgraph-4xx/src                                                    |
|jpgraph-4xx |https://jpgraph.net/download/                                                         |
|oauth       |https://www.phpclasses.org/package/7700-PHP-Authorize-and-access-APIs-using-OAuth.html|




2) Do souboru `oauth/oauth_configuration.json` přidejte konfiguraci pro OSM:

```
		"OpenStreetMap.org":
		{
			"oauth_version": "1.0a",
			"request_token_url": "https://www.openstreetmap.org/oauth/request_token",
			"dialog_url": "https://www.openstreetmap.org/oauth/authorize",
			"access_token_url": "https://www.openstreetmap.org/oauth/access_token",
			"authorization_header": false
		},

```
