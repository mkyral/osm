# import/ceska_posta


Skript na konverzi datasetu České pošty obsahující údaje o poštovních schránkách do formátu GeoJson, který je následně použit v cz instanci [POI-Importer](https://github.com/POI-Importer/POI-Importer.github.io)u.


## Dataset

Ke stažení na adrese https://www.ceskaposta.cz/ke-stazeni/zakaznicke-vystupy
(Seznam poštovních schránek).

Aktualizace jednou měsíčně, vždy začátkem měsíce.

Zip archív obsahuje csv, jehož formát je popsán v "certifikátu zákaznického výstupu".

## Skript

Konverzní skript `process_file.py` je napsán v pythonu, jak jeho přípona napovídá ;-)

Očekává minimálně dva parametry

* `<Vstupní soubor>` - povinný parametr - csv soubor se seznamem schránek
* `<typ výstupu>` - jaký výstup se má generovat - povinný parametr
* `<prefix_výstupního_souboru>` - pro typy výstupu 'geojson' a 'sql' povinné

 **Typ výstupu:**

| Výstup    | Popis                             |
|-----------|-----------------------------------|
| `tiles  ` | GeoJson dlaždice pro POI-Importer |
| `geojson` | jeden velký GeoJson soubor        |
| `sql    ` | skript s inserty pro statistiky   |


### Příklady volání:

```
python process_file.py POST_SCHRANKY_201802.csv tiles # vygeneruje dlaždice
```

```
python process_file.py POST_SCHRANKY_201802.csv geojson vystup_1802 # vygeneruje geojson soubor vystup_1802.geojson
```
### Funkce programu

* Načtení vstupního csv datasetu. Je očekáván standardní formát jména: `POST_SCHRANKY_YYYYMM.csv`
* Převod souřadnic z Křováka do formátu WGS-84
* Konsolidace a převod času výběru schránky do OSM formátu
* V režimu `tiles` a `geojson`
    * Dohledání chybějících souřadnic v souborech `osm_coors.csv` a `missing_coordinates.csv`
    * Vygenerování výstupního souboru `prefix_výstupního_souboru.geojson` nebo geojson souřadnic
* V režimu `sql`
    * Vygeneruje soubor pro nahrání dat do databáze, kde je dále lze porovnat s OSM

### Korekce

Korekce souřadnic pro již spárované schránky jsou přebírány z OpenStreetMap.
Je očekáván soubor `osm_coors.csv` ve formátu

```shell
$ head osm_coors.csv
ref;lat;lon;
60010:433;49.2469761;16.5824712
60010:423;49.2405448;16.5734043
60010:419;49.2397347;16.5871328
60010:312;49.2313023;16.5706483
60010:240;49.1800089;16.6050624
72572:199;49.7699101;18.3101275
72572:19;49.7774374;18.3995176
72572:93;49.7849243;18.3744997
72572:18;49.7684991;18.3807913
...
```

### Chybějící souřadnice

V datasetu je stále cca 3 ticíce řádků (únor 2018), které nemají uvedeny souřadnice. Pouze adresu a popis umístění. Pro tyto řádky byla pomocí geokódování získána přibližná poloha. Program očekává soubor `missing_coordinates.csv`, kde tyto chybějící souřadnice dohledává. (Pokud nebyly nalezeny přesnější souřadnice v OSM.)

```shell
$ head missing_coordinates.csv
ref;lat;lon
10003:218;50.0487432;14.4349539
10003:246;50.0620353;14.4357024
10003:256;50.0547832;14.4237647
10003:269;50.0300518;14.4571304
10003:270;50.0300518;14.4571304
10003:271;50.0300518;14.4571304
10003:278;50.0200175;14.4462181
10003:284;50.0442172;14.4505459
10003:295;50.0186456;14.4460122
...
```

### Závislosti

* python3
* python balíčky

    * pyproj
    * geojson (https://github.com/frewsxcv/python-geojson)

## POI-importer

Vygenerovaná geojson data jsou vizualizována [POI-Importeru](https://github.com/POI-Importer/POI-Importer.github.io). Je to webová javascriptová aplikace založená na knihovně [Leaflet](http://leafletjs.com/), která zobrazí data z vybraného datasetu a přes overpass dohledává dané entity (třeba poštovní schránky) v databázi OpenStreetMap a oba záznamy porovná. Dle výsledku porovnání pak daný bod zabarví. Od červené (Nenalezeno v OSM), přes oranžovou, žlutou a světle zelenou (nalezeno v OSM, některé porovnávané tagy nesouhlasí) až po sytě zelenou (nalezeno v OSM a všechny porovnávané tagy souhlasí).

Pro účely importu schránek České pošty byl POI-Importer mírně modifikován. Úprava spočívá v přidání možnosti zobrazit u daného bodu dodatečné informace pomocí speciálního tagu `_note`. Fork je na [githubu](https://github.com/mkyral/POI-Importer.github.io), instance běží na [http://osm.kyralovi.cz/POI-Importer-testing](http://osm.kyralovi.cz/POI-Importer-testing/#map=14/49.5592/15.9565&datasets=CZECPbox).


## Statistiky

Složka `stats` obsahuje php skript zobrazující statistiky Česká pošta vs. OSM. Hlavní stránka sumárně za jednotlivá depa, kliknutím na depo se zobrazí detail depa - jeho schránky a srovnání stavu s OSM.

Složka `stats/dba` obsahuje potřebné DBA skripty pro Postgress. Využívá se existující OSM databáze [poloha.net](https://poloha.net), takže ve skriptech není plnění databáze daty z OSM.

Statistiky běží na adrese: http://josm.poloha.net/cz_pbox/



