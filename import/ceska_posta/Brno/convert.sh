#!/usr/bin/env bash

OUT_JSON=schranky_brno.geojson

# Header
cat > $OUT_JSON <<EOT
{
  "type": "FeatureCollection",
  "features":
  [
EOT

# Body
cat schranky-brno-final.gpx |egrep "lat=|desc" \
                            |grep -v "bound" \
                            |sed -e 's/  <wpt lat="//' -e 's/    <desc>//' -e 's/<\/desc>//' -e 's/">.*$/|/' -e 's/" lon="/|/' \
                            |awk '{key=$0; getline; print key $0;}' \
                            |while IFS='|' read LAT LON DESC
do

    LAT_ORIG=""
    LON_ORIG=""
    COORD="$(grep "$(LANG=C printf "%.*f %.*f;\n" 6 $LAT 6 $LON)" ../corrections.csv |cut -d ';' -f 2)"

    if [ "$COORD" ]
    then
        LON_ORIG="$LON"
        LAT_ORIG="$LAT"

        LON="${COORD#* }"
        LAT=${COORD% *}
        echo "Coors $LAT_ORIG, $LON_ORIG corrected to $LAT, $LON"
        DESC="${DESC}<br><br><u>Souřadnice korigovány!</u><br><b>Původní souřadnice:</b> $LAT_ORIG, $LON_ORIG"
    fi

cat >> $OUT_JSON <<EOT
    $SEPARATOR{
      "type": "Feature",
      "properties": {
          "amenity": "post_box",
          "operator": "Česká pošta, s.p.",
          "_note": "<br><b>Adresa:</b> $DESC"
      },
      "geometry": {
        "type": "Point",
        "coordinates": [$LON, $LAT]
      }
    }
EOT
SEPARATOR=","
done

# Footer
echo "
  ]
}" >> $OUT_JSON





