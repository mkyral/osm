#!/usr/bin/env bash

IN_FILE="$1"
IN_DEPO="$2"

if [ -z "$IN_FILE" -o ! -e "$IN_FILE" ]
then
  echo "Error: Missing or non existing input file"
  echo "Usage: $0 <INPUT_FILE> [<DEPO>]"
  exit 1
fi

if [ "$IN_DEPO" ]
then
  IN_FILE_DEPO="${IN_FILE}_${IN_DEPO}"
  head -n 1 "$IN_FILE" > "$IN_FILE_DEPO"
  tail -n +2 "$IN_FILE" | egrep -a "^${IN_DEPO};" >> "$IN_FILE_DEPO"
  IN_FILE="$IN_FILE_DEPO"
fi

# output files
json_file=cpost_pos_box${IN_DEPO}.geojson
missing_coors=missing_coors${IN_DEPO}.csv
out_of_bbox=out_of_bbox${IN_DEPO}.txt

log_file=
rm -f $missing_coors $out_of_bbox

# BBOX for import
MIN_LAT=48.55
MAX_LAT=51.06
MIN_LON=12.09
MAX_LON=18.87

processed=0
correct=0
no_coors=0
oo_bbox=0

# cd tmp
tmp_rec=$(mktemp)

write_GeoJSON()
{
    dl="$1"
    echo "${dl}{
        \"type\": \"Feature\",
        \"properties\": {
            \"amenity\": \"post_box\",
            \"ref\": \"${old_key}\",
            \"operator\": \"Česká pošta, s.p.\""

    # Put some additional info in note
    ## Original coordinates corrected
    ORIG=""
    if [ "$LAT_ORIG" ]
    then
        ORIG="<br><br><u>Souřadnice korigovány!</u><br><b>Původní souřadnice:</b> $LAT_ORIG, $LON_ORIG"
    fi

    # Description and address
    if [ "$ADRESA" ]
    then
        echo ", \"_note\": \"<br><b>Poznámka:</b> "$(echo $MISTO_POPIS |sed "s/\"/\\\\\"/g")"<br><b>Adresa:</b> ${ADRESA}${ORIG}\""
    else
        echo ", \"_note\": \"<br><b>Poznámka:</b> "$(echo $MISTO_POPIS |sed "s/\"/\\\\\"/g")"<br><b>Adresa:</b> $OKRES; $OBEC; ${CAST_OBCE}${ORIG}\""
    fi

    # Collecting times
    if [ "$CT" ]; then echo "  ,\"collection_times\": \"$CT\""; fi


    #Geometry
    echo "    },
            \"geometry\": {
                \"type\": \"Point\",
                \"coordinates\": [
                    $LON,
                    $LAT
                ]
            }
        }"

}

echo "{
    \"type\": \"FeatureCollection\",
    \"features\": [
" > $json_file


old_key=""
ct_delim=""
CT=""
delim=""

tail -n +2 $IN_FILE | iconv -f cp1250 -t utf-8 |cut -d ";" -f 1,3- |sort | while IFS=';' read W_PSC W_ID W_ADRESA W_SOUR_X W_SOUR_Y W_MISTO_POPIS W_CAST_OBCE W_OBEC W_OKRES W_CAS W_OMEZENI
do
    (( processed++ ))
    echo "$processed/$correct/$no_coors/$oo_bbox"

    if [ -z "$W_SOUR_X" ]
    then
        echo "Missing Coordinates: ${W_ADRESA}; ${W_MISTO_POPIS}; ${W_CAST_OBCE}; ${W_OBEC}; ${W_OKRES}; ${W_CAS}; ${W_OMEZENI}"
        echo "${W_PSC};${W_ID};${W_ADRESA};${W_SOUR_X};${W_SOUR_Y};${W_MISTO_POPIS};${W_CAST_OBCE};${W_OBEC};${W_OKRES};${W_CAS};${W_OMEZENI}" >> $missing_coors
        (( no_coors++ ))
        continue
    fi

#     key=$(echo "${W_PSC}${W_ADRESA}${W_SOUR_X}${W_SOUR_Y}${W_MISTO_POPIS}${W_CAST_OBCE}${W_OBEC}${W_OKRES}" |tr -d "[:blank:],.:;-" | iconv -f utf-8 -t ascii//TRANSLIT |tr "[:lower:]" "[:upper:]")

    key="${W_PSC}/${W_ID}"

#     echo "old: $old_key"
#     echo "key: $key"

    if [ "$key" != "$old_key" ]
    then
        if [ "$old_key" ]
        then
            # Write GeoJSON
            write_GeoJSON $delim >>$json_file
            (( correct++ ))
            delim=","
        fi

        old_key="$key"
        ct_delim=""
        CT=""

        PSC="$W_PSC"
        SCHR_CISLO="${W_ID}"
        ADRESA="$W_ADRESA"
        SOUR_X="$W_SOUR_X"
        SOUR_Y="$W_SOUR_Y"
        MISTO_POPIS="$W_MISTO_POPIS"
        CAST_OBCE="$W_CAST_OBCE"
        OBEC="$W_OBEC"
        OKRES="$W_OKRES"
        CAS="$W_CAS"
        OMEZENI="$W_OMEZENI"

        # Convert coordinates
        read LON LAT X < <(echo "-${SOUR_Y} -${SOUR_X}" | \
                        cs2cs -f "%f" +proj=krovak +ellps=bessel \
                                        +towgs84=570.8,85.7,462.8,4.998,1.587,5.261,3.56 \
                                        +to +init=epsg:4326 \
        )

        LAT_ORIG=""
        LON_ORIG=""
        CORR="$(grep "$LAT $LON;" corrections.csv |cut -d ';' -f 2)"
        if [ "$CORR" ]
        then
            LON_ORIG="$LON"
            LAT_ORIG="$LAT"

            LON="${CORR#* }"
            LAT=${CORR% *}
            echo "Coors $LAT_ORIG, $LON_ORIG corrected to $LAT, $LON"
        fi

        if [ $(echo "$MIN_LON > $LON" |bc -l) -gt 0 -o \
             $(echo "$MAX_LON < $LON" |bc -l) -gt 0 -o \
             $(echo "$MIN_LAT > $LAT" |bc -l) -gt 0 -o \
             $(echo "$MAX_LAT < $LAT" |bc -l) -gt 0    \
           ]
        then
            echo "Mimo BBOX: $LAT, $LON (${SOUR_Y} -${SOUR_X}) - ${W_PSC}, ${W_ZKRNAZ_POSTY}, ${W_ADRESA}, ${W_MISTO_POPIS}"
            echo "${LAT};${LON};${W_PSC};${W_ZKRNAZ_POSTY};${W_ADRESA};${W_SOUR_X};${W_SOUR_Y};${W_MISTO_POPIS};${W_CAST_OBCE};${W_OBEC};${W_OKRES};${W_CAS};${W_OMEZENI}" >> $out_of_bbox
            (( oo_bbox++ ))
            continue
        fi


    fi

#    echo "${OMEZENI:0:3} - ${OMEZENI}"

    CT_DAYS=$(echo "${W_OMEZENI}" |cut -d " " -f 1)

    if [ "${#W_CAS}" -eq 5 ]
    then
      CT_TIME="$W_CAS"
    else
      CT_TIME="0$W_CAS"
    fi

    if [ "$CT_DAYS" ]
    then
        W_DAYS=$(echo "$CT_DAYS" |sed -e "s/1/Mo/; s/2/Tu/; s/3/We/; s/4/Th/; s/5/Fr/; s/6/Sa/; s/7/Su/")
        CT=$(echo "${CT}${ct_delim}${W_DAYS} ${CT_TIME}")
        ct_delim=", "
    fi

#      echo "[$LAT; $LON] $MISTO_POPIS: $CT"
     write_GeoJSON $delim >$tmp_rec

done

# Write GeoJSON
cat $tmp_rec >>$json_file

# finish geojson file
echo "]" >> $json_file
echo "}" >> $json_file

# Cleanup
[ -e "$IN_FILE_DEPO" ] && rm -f "$IN_FILE_DEPO"

echo "----------------------------------------------------------------------"
# echo "Final stats: "
# echo "    Processed: $processed"
# echo "    Correct: $correct"
# echo "    No coordinates: $no_coors"
# echo "    Out of BBOX: $oo_bbox"
# echo

