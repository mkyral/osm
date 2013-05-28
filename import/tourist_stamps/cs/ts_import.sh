#!/bin/bash

##
## A script for initial import of Czech tourist stamps
## (http://www.turisticke-znamky.cz)
##
## Author: Marian Kyral <mkyral@email.cz>
## Version 1, 28.05.2013
##
## License: Public domain
##

if [ $# -ne 3 ]
then
  echo "usage: $0 <category> <input csv file> <output osm file>"
  exit
fi

CAT="$1"
INPUT_FILE="$2"
OUTPUT_FILE="$3"

if [ "$CAT" = "ALL" ]
then
  # some character present on all lines ;-)
  CAT=";"
fi

TMP_FILE_IN=/tmp/tz_tmp_in.$$
TMP_FILE_OUT=/tmp/tz_tmp_out.$$
TMP_FILE_BOU=/tmp/tz_tmp_bou.$$

MIN_LAT=99999
MAX_LAT=0

MIN_LON=99999
MAX_LON=0

ID=100

LINE_NO=0
FLINE_NO=0

# functions
compare_decimals ()
{

  RET=$(echo $1 $2 |awk '{ print $1 - $2 }')

  if [ "$RET" = "0" ]
  then
    echo "eq"
  elif [ "$(echo $RET |cut -c 1)" = "-" ]
  then
    echo "lt"
  else
    echo "gt"
  fi
}

# Convert character set win1250 to utf8
iconv -f WINDOWS-1250 -t UTF8 "${INPUT_FILE}" -o "${TMP_FILE_IN}"

# Read file
OLD_IFS=$IFS
IFS=";"

cat "${TMP_FILE_IN}" |tr -d '\r'| tail -n +5 |grep -v '"nevyrobena"'| sed -e 's/;"/;/g' -e 's/";/;/g' -e 's/"$//g' |grep -i "$CAT" | while read NO NAME CATEGORY DISTRICT PUBLISHED SP1 W1 SP2 W2 SP3 W3 SP4 W4 SP5 W5 SP6 W6 SP7 W7 SP8 W8 SP9 W9 SP10 W10 SP11 W11 SP12 W12 SP13 W13 LAT LON
do

  echo -n "."
  LINE_NO=$((LINE_NO + 1))

  if [ -z "$LAT" -o -z "$LON" -o -z "$NO" -o -z "$NAME" ]
  then
    echo "Incomplete data on line: $LINE_NO"
    echo "LAT: $LAT; LON: $LON; NO: $NO; NAME: $NAME"
    continue
  fi

  # LAT/LON - use decimal dot
  LAT=${LAT/,/.}
  LON=${LON/,/.}

  FLINE_NO=$((FLINE_NO + 1))

  NODE_ID=$ID
  ID=$((ID + 10))
  RELATION_ID=$ID
  ID=$((ID + 10))

  # boundary
  BCHANGE=0
  if [ "$(compare_decimals $LAT $MIN_LAT)" = "lt" ]; then MIN_LAT=$LAT; BCHANGE=1; fi
  if [ "$(compare_decimals $LAT $MAX_LAT)" = "gt" ]; then MAX_LAT=$LAT; BCHANGE=1; fi
  if [ "$(compare_decimals $LON $MIN_LON)" = "lt" ]; then MIN_LON=$LON; BCHANGE=1; fi
  if [ "$(compare_decimals $LON $MAX_LON)" = "gt" ]; then MAX_LON=$LON; BCHANGE=1; fi

  if [ $BCHANGE -eq 1 ]
  then
    echo "<bounds minlat='${MIN_LAT}' minlon='${MIN_LON}' maxlat='${MAX_LAT}' maxlon='${MAX_LON}' origin='CGImap 0.1.0' />" > "$TMP_FILE_BOU"
  fi


  if [ "$CATEGORY" ]
  then
    # NOTE: tr does not work correctly with diacritics chars on my system. AWK is just a workaround
    CT="$(echo ${CATEGORY}| cut -c 1)$(echo ${CATEGORY}| cut -c 2- |awk '{ print tolower($0) }')"
  else
    CT=""
  fi

  # create fixme node
  echo "<node id='-$NODE_ID' action='modify' visible='true' lat='$LAT' lon='$LON'>" >> "$TMP_FILE_OUT"
  echo "  <tag k='tourism' v='attraction' />" >> "$TMP_FILE_OUT"
  echo "  <tag k='name' v='${NAME}' />" >> "$TMP_FILE_OUT"
  echo "  <tag k='fixme' v='Dočasný bod relace turistické známky ${NO}. ${NAME}. Opravte prosim dle pokynů na http://wiki.openstreetmap.org/wiki/XXX' />" >> "$TMP_FILE_OUT"
  echo "</node>" >> "$TMP_FILE_OUT"

  # create relation
  echo "<relation id='-${RELATION_ID}' action='modify' visible='true'>" >> "$TMP_FILE_OUT"
  echo "  <member type='node' ref='-${NODE_ID}' role='attraction' />" >> "$TMP_FILE_OUT"
  echo "  <tag k='type' v='checkpoint' />" >> "$TMP_FILE_OUT"
  echo "  <tag k='checkpoint' v='tourism' />" >> "$TMP_FILE_OUT"
  echo "  <tag k='checkpoint:type' v='tourist_stamp' />" >> "$TMP_FILE_OUT"
  if [ "$CT" ]; then echo "  <tag k='checkpoint:category:cz' v='$CT' />" >> "$TMP_FILE_OUT"; fi
  echo "  <tag k='name' v='${NO}. ${NAME}' />" >> "$TMP_FILE_OUT"
  echo "  <tag k='ref' v='TSCZ:${NO}' />" >> "$TMP_FILE_OUT"
  echo "  <tag k='source' v='turisticke-znamky' />" >> "$TMP_FILE_OUT"
  echo "  <tag k='website' v='http://www.turisticke-znamky.cz/znamka_.php?id=${NO}' />" >> "$TMP_FILE_OUT"

  # NOTE: & character is replaced by html entity.
  if [ "$SP1" ]; then echo "  <tag k='checkpoint:sales_point:1' v='${SP1/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W1" ]; then echo "  <tag k='checkpoint:sales_point:web:1' v='${W1/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP2" ]; then echo "  <tag k='checkpoint:sales_point:2' v='${SP2/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W2" ]; then echo "  <tag k='checkpoint:sales_point:web:2' v='${W2/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP3" ]; then echo "  <tag k='checkpoint:sales_point:3' v='${SP3/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W3" ]; then echo "  <tag k='checkpoint:sales_point:web:3' v='${W3/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP4" ]; then echo "  <tag k='checkpoint:sales_point:4' v='${SP4/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W4" ]; then echo "  <tag k='checkpoint:sales_point:web:4' v='${W4/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP5" ]; then echo "  <tag k='checkpoint:sales_point:5' v='${SP5/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W5" ]; then echo "  <tag k='checkpoint:sales_point:web:5' v='${W5/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP6" ]; then echo "  <tag k='checkpoint:sales_point:6' v='${SP6/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W6" ]; then echo "  <tag k='checkpoint:sales_point:web:6' v='${W6/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP7" ]; then echo "  <tag k='checkpoint:sales_point:7' v='${SP7/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W7" ]; then echo "  <tag k='checkpoint:sales_point:web:7' v='${W7/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP8" ]; then echo "  <tag k='checkpoint:sales_point:8' v='${SP8/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W8" ]; then echo "  <tag k='checkpoint:sales_point:web:8' v='${W8/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP9" ]; then echo "  <tag k='checkpoint:sales_point:9' v='${SP9/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W9" ]; then echo "  <tag k='checkpoint:sales_point:web:9' v='${W9/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP10" ]; then echo "  <tag k='checkpoint:sales_point:10' v='${SP10/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W10" ]; then echo "  <tag k='checkpoint:sales_point:web:10' v='${W10/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP11" ]; then echo "  <tag k='checkpoint:sales_point:11' v='${SP11/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W11" ]; then echo "  <tag k='checkpoint:sales_point:web:11' v='${W11/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP12" ]; then echo "  <tag k='checkpoint:sales_point:12' v='${SP12/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W12" ]; then echo "  <tag k='checkpoint:sales_point:web:12' v='${W12/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$SP13" ]; then echo "  <tag k='checkpoint:sales_point:13' v='${SP13/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi
  if [ "$W13" ]; then echo "  <tag k='checkpoint:sales_point:web:13' v='${W13/&/&amp;}' />" >> "$TMP_FILE_OUT"; fi

  echo "</relation>" >> "$TMP_FILE_OUT"

done

# complete the file

echo "<?xml version='1.0' encoding='UTF-8'?>" > "$OUTPUT_FILE"
echo "<osm version='0.6' upload='true' generator='TZIMP'>" >> "$OUTPUT_FILE"
cat "$TMP_FILE_BOU" >> "$OUTPUT_FILE"
cat "$TMP_FILE_OUT" >> "$OUTPUT_FILE"
echo "</osm>" >> "$OUTPUT_FILE"

echo
echo "Procesing finished."
