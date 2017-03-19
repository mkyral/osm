import/ceska_posta
===

Skript na konverzi datasetu České pošty obsahující údaje o poštovních schránkách do formátu geojson, který je následně použit v cz instanci [POI-Importer](https://github.com/POI-Importer/POI-Importer.github.io)u.


dataset
---
Ke stažení na adrese https://www.ceskaposta.cz/ke-stazeni/zakaznicke-vystupy
(Seznam poštovních schránek). Je aktualizován jednou měsíčně.

Zip archív obsahuje csv, jehož formát je popsán v "certifikátu zákaznického výstupu".

skript
---
Konverzní skript se jmenuje: `prepare_data_simple.sh` a akceptuje dva parametry

* <Vstupní soubor> - povinný parametr - csv soubor se seznamem schánek
* <depo> - číslo depa - nepovinný parametr, který omezuje zpracovávaný rozsah na vybrané depo

Příklady volání:


```
./prepare_data_simple.sh POST_SCHRANKY_201703.csv # vše
```

```
 ./prepare_data_simple.sh POST_SCHRANKY_201703.csv 60010  # omezeno na Brno
```

Skript vygeneruje geojson soubor `cpost_pos_box.geojson` nebo `cpost_pos_box<číslo depa>.geojson`.
Tento soubor je pak následně zpracován (rozdělen na dlaždice) pomocí skriptu `tile_geojson.js`, který je součástí POI-Importeru.

```
node tile_geojson.js -d cesta/k/souboru/cpost_pos_box.geojson -r datasets/Czech-ceska-posta-schranky
```

korekce
---
Protože dataset není zcela přesný, obsažené souřadnice mnohdy ukazují jen na budovu, před kterou je schránka (a někdy je schránka před úplně jinou budovou), vznikla potřeba evidovat tyto rozdíly a pozici těchto nepřesně umístěných schránek během zpracování opravit tak, aby bylo zřejmé, že schránku již někdo zkontroloval.

K tomu je určen soubor `corrections.csv`

```
#original latlon;corrected latlon
49.187420 16.615005;49.189101 16.614177
49.198716 16.598422;49.199258 16.596830
49.212358 16.597009;49.212774 16.600971
49.212036 16.596555;49.212974 16.596330
49.191157 16.613106;49.190580 16.611378
```
Bohužel, vzhledem k tomu, že dataset neobsahuje identifikátory schránek, není možné tyto posuny jednoznačně identifikovat a v případě, že dojde ke změně souřadnic, bude potřeba korekční soubor opravit.

omezení
---
* V datasetu je také 3223 řádků (březen 2017), které nemají uvedeny souřadnice. Pouze adresu. Tyto řádky jsou v současné době vloženy do chybového souboru `missing_coors.csv` a dále ignorovány.  Přibližné souřadnice je možné získat z popisu schránky buď ručně, nebo pomocí geokódování.
* Vícenásobná doba výběru nemusí být zpracována správně (dny nejsou setříděny)

závislosti
---
* bash
* iconv - pro převod znakové sady datasetu





