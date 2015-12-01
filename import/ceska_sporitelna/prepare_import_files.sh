#!/usr/bin/env bash

# Ceska sporitelna import script for OSM
# Copyright (C) 2015  Marián Kyral <mkyral@email.cz>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# check bash version
if [ -z "$BASH_VERSION" -o ${BASH_VERSION:0:1} -lt 4 ]
then
  echo "Sorry, bash version 4 or higher is required!" >&2
  exit 1
fi

# check for important programs
if [ -z "$(which bc 2>/dev/null)" ]
then
  echo "Sorry, bc not found!" >&2
  exit 1
fi

if [ -z "$(which xml2 2>/dev/null)" ]
then
  echo "Sorry, xml2 not found!" >&2
  exit 1
fi

if [ -z "$(which wget 2>/dev/null)" ]
then
  echo "Sorry, wget not found!" >&2
  exit 1
fi


[ ! -e tmp ] && mkdir tmp
cd tmp
# [ -f gps_poi_garmin.xml ] && rm -f gps_poi_garmin.xml
# wget "http://www.csas.cz/banka/content/inet/internet/cs/gps_poi_garmin.xml"
#
# xml2 < gps_poi_garmin.xml > gps_poi_garmin.txt
#
# [ -f gps_ATM_poi_garmin.xml ] && rm -f gps_ATM_poi_garmin.xml
# wget "http://www.csas.cz/banka/content/inet/internet/cs/gps_ATM_poi_garmin.xml"
#
# xml2 < gps_ATM_poi_garmin.xml > gps_ATM_poi_garmin.txt

OLD_IFS="$IFS"
# Convert opening hours to OSM format
optimize_opening_hours_key()
{
  # initialize variables

  declare -a oh_days=()
  declare -a opening_hours=()
  declare -a data=("$po" "$ut" "$st" "$ct" "$pa" "$so" "$ne");
  declare -a days=("Mo" "Tu" "We" "Th" "Fr" "Sa" "Su")

  IFS="$OLD_IFS"

  # go through days and group days with the same opening_hours
  for idx in $(seq 0 $((${#data[@]}-1)))
  do
#      echo "$idx: ${data[$idx]}"
    if [ "${data[$idx]}" = "closed" ];
    then
      continue;
    else
      if [ ${#opening_hours[@]} -eq 0 ]
      then
        opening_hours[0]="${data[$idx]}"
        oh_days[0]="${days[$idx]},"
      else
        for oh_idx in $(seq 0 $((${#opening_hours[@]}-1)))
        do
          if [ "${opening_hours[$oh_idx]}" = "${data[$idx]}" ]
          then
            oh_days[$oh_idx]="${oh_days[$oh_idx]}${days[$idx]},"
            continue 2
          fi
        done
        opening_hours[${#opening_hours[@]}]=${data[$idx]}
        oh_days[${#oh_days[@]}]="${days[$idx]},"
      fi
    fi
  done

  # finalize - put it to the same row
  local ret=""
  for oh_idx in $(seq 0  $((${#opening_hours[@]}-1)))
  do
#     echo "$(echo ${oh_days[$oh_idx]} |sed 's/,$//') ${opening_hours[$oh_idx]}"
    local dval="$(echo ${oh_days[$oh_idx]} |sed 's/,$//')"

    # Fix wrong value "0:00"
    if [ $(echo "${opening_hours[$oh_idx]}" |egrep -c "^0:") -gt 0 ]
    then
      opening_hours[$oh_idx]="0${opening_hours[$oh_idx]}"
    fi

    # Change 23:59 to 24:00 according to opening_hours wiki
    if [ $(echo "${opening_hours[$oh_idx]}" |grep -c "23:59") -gt 0 ]
    then
      opening_hours[$oh_idx]=$(echo "${opening_hours[$oh_idx]}" |sed "s/23:59/24:00/g")
    fi

    # Optimize opening hours value
    if [ -z "${opening_hours[$oh_idx]}" -o "${opening_hours[$oh_idx]}" = "null" ]
    then
      continue
    elif [ "$dval" = "Mo,Tu,We,Th,Fr,Sa,Su" -a "${opening_hours[$oh_idx]}" = "closed" ]
    then
      continue
    elif [ "$dval" = "Mo,Tu,We,Th,Fr,Sa,Su" -a "${opening_hours[$oh_idx]}" = "00:00-24:00" ]
    then
      ret="24/7"
      break
    elif [ "$dval" = "Mo,Tu,We,Th,Fr,Sa,Su" ]
    then
      dval="Mo-Su"
    elif [ "$dval" = "Mo,Tu,We,Th,Fr" ]
    then
      dval="Mo-Fr"
    fi

    # If opening hours value does not contains number, change it to note
    if [ $(echo "${opening_hours[$oh_idx]}" |egrep -c "^[^0-9]") -gt 0 ]
    then
      opening_hours[$oh_idx]="\"${opening_hours[$oh_idx]}\""
    fi

    ret="${ret}${dval} ${opening_hours[$oh_idx]};"
  done

#   if [ "$ret" = "Mo,Tu,We,Th,Fr,Sa,Su 00:00-23:59;" ];
#   then
#     echo "24/7"
#   else
    echo "$(echo $ret |sed 's/;$//')"
#   fi
}

write_text()
{
  echo "======================================================="
  echo "Coor: $lat, $lon"
  echo "Name: $name"
  if [ "$type" ] ; then echo "Type: $type"; fi
  echo "Street: $addr_street"
  echo "City: $addr_city"
  echo "Psč: $addr_psc"
  echo
  echo "Mo:$po"
  echo "Tu:$ut"
  echo "We:$st"
  echo "Th:$ct"
  echo "Fr:$pa"
  echo "Sa:$so"
  echo "Su:$ne"
  echo
}

write_csv_line()
{
  echo "\"$lat\";\"$lon\";\"$name\";\"$addr_street\";\"$addr_city\";\"$addr_psc\";\"$po\";\"$ut\";\"$st\";\"$ct\";\"$pa\";\"$so\";\"$ne\";\"$type\""
}

write_osm_bank()
{
  echo "<node id='-$((id++))' action='modify' visible='true' lat='$lat' lon='$lon'>"
  echo "  <tag k='amenity' v='bank' />"
  echo "  <tag k='bic' v='GIBACZPX' />"
  echo "  <tag k='brand' v='Česká spořitelna' />"
  echo "  <tag k='name' v='Česká spořitelna, $name' />"
  if [ "$oph" ]; then echo "  <tag k='opening_hours' v='$oph' />"; fi
  echo "  <tag k='operator' v='Česká spořitelna' />"
  if [ "$type" ]; then echo "  <tag k='description' v='$type' />"; fi
  echo "  <tag k='contact:website' v='http://www.csas.cz' />"
  echo "  <tag k='source' v='ceska_sporitelna_gpx' />"
  echo "</node>"
}

write_geojson_bank()
{
  echo "${delim}{
            \"type\": \"Feature\",
            \"properties\": {
                \"name\": \"$(echo "Česká spořitelna, ${name}" |sed "s/\"/\\\\\"/g")\",
                \"bic\": \"GIBACZPX\",
                \"brand\": \"Česká spořitelna\",
                \"amenity\": \"bank\",
                \"operator\": \"Česká spořitelna\",
                \"contact:website\": \"http://www.csas.cz\",
                \"source\": \"ceska_sporitelna_gpx\""
  if [ "$oph" ]; then echo "  ,\"opening_hours\": \"$(echo "$oph" |sed "s/\"/\\\\\"/g")\""; fi
  if [ "$type" ]; then echo "  ,\"description\": \"$type\""; fi
  echo "    },
            \"geometry\": {
                \"type\": \"Point\",
                \"coordinates\": [
                    $lon,
                    $lat
                ]
            }
        }"
  export delim=","
}

write_osm_atm()
{
  echo "<node id='-$((id++))' action='modify' visible='true' lat='$lat' lon='$lon'>"
  echo "  <tag k='amenity' v='atm' />"
  echo "  <tag k='network' v='Česká spořitelna' />"
  echo "  <tag k='name' v='$name' />"|sed "s/&/&amp;/g"
  if [ "$oph" ]; then echo "  <tag k='opening_hours' v='$oph' />"; fi
  echo "  <tag k='operator' v='Česká spořitelna' />"
  if [ "$type" ]; then echo "  <tag k='description' v='$type' />"; fi
  echo "  <tag k='contact:website' v='http://www.csas.cz' />"
  echo "  <tag k='source' v='ceska_sporitelna_gpx' />"
  echo "</node>"
}

write_geojson_atm()
{
  echo "${delim}{
            \"type\": \"Feature\",
            \"properties\": {
                \"name\": \"$(echo "${name}" |sed "s/\"/\\\\\"/g")\",
                \"network\": \"Česká spořitelna\",
                \"amenity\": \"atm\",
                \"operator\": \"Česká spořitelna\",
                \"contact:website\": \"http://www.csas.cz\",
                \"source\": \"ceska_sporitelna_gpx\""
  if [ "$oph" ]; then echo "  ,\"opening_hours\": \"$(echo "$oph" |sed "s/\"/\\\\\"/g")\""; fi
  if [ "$type" ]; then echo "  ,\"description\": \"$type\""; fi
  echo "    },
            \"geometry\": {
                \"type\": \"Point\",
                \"coordinates\": [
                    $lon,
                    $lat
                ]
            }
        }"
  export delim=","
}

process_file()
{
  p_input_file="$1"
  p_type="$2"

  if [ -z "$p_input_file" -o -z "$p_type" ]
  then
    return 1
  fi

  # Prepare file:
  # - grep only relevant rows, take only values and merge each four rows to one row.
  # - Separate address column and split opening hours per day
  #
  cat $p_input_file |egrep "/gpx/wpt/@|/gpx/wpt/name|/gpx/wpt/cmt" |cut -d "=" -f 2 |paste - - - - -d";" | \
      sed "s/ Provozní doba: //; s/Po: /;/g; s/ Út: /;/g; s/ St: /;/g; s/ Čt: /;/g; s/ Pá: /;/g; s/ So: /;/g; s/ Ne: /;/g;" > $work_csv


  while IFS=";" read lat lon name addr mo tu we th fr sa su
  do
  #   echo "$lat|$lon|$name|$addr|$mo|$tu|$we|$th|$fr|$sa|$su";

    # check coordinates and move them a little when there is an duplicity
    local latlon="${lat},${lon}"
    dupl_cnt=${dupl_coors[$latlon]}
    if [ "$dupl_cnt" ]
    then
      echo "Duplicated coordinates #$((dupl_cnt + 1)) for $latlon found"
      case $dupl_cnt in
        0)   ;;
        1)   lon=$(echo "$lon - 0.00005" |bc);;
        2)   lon=$(echo "$lon + 0.00005" |bc);;
        3)   lon=$(echo "$lon - 0.00005" |bc); lat=$(echo "$lat - 0.00005" |bc);;
        4)   lat=$(echo "$lat - 0.00005" |bc);;
        5)   lon=$(echo "$lon + 0.00005" |bc); lat=$(echo "$lat - 0.00005" |bc);;
        6)   lon=$(echo "$lon - 0.00005" |bc); lat=$(echo "$lat - 0.0001" |bc);;
        7)   lat=$(echo "$lat - 0.0001"  |bc);;
        8)   lon=$(echo "$lon + 0.00005" |bc); lat=$(echo "$lat - 0.0001" |bc);;
        9)   lon=$(echo "$lon - 0.00005" |bc); lat=$(echo "$lat - 0.00015" |bc);;
        10)  lat=$(echo "$lat - 0.00015"  |bc);;
        11)  lon=$(echo "$lon + 0.00005" |bc); lat=$(echo "$lat - 0.00015" |bc);;
      esac
      dupl_coors[$latlon]=$((++dupl_cnt))
    fi

    name="$(echo $name |sed 's/^\(.\)/\U\1/g; s/ALBERT/Albert/g; s/BILLA/Billa/g; s/BIG/Big/g; s/TESCO/Tesco/g;
                            s/KAUFLAND/Kaufland/g; s/GLOBUS/Globus/g; s/HORNBACH/Hornbach/g; s/LIDL/Lidl/g;
                            s/PENNY MARKET/Penny Market/g; s/TERNO/Terno/g; s/COOP/Coop/g; s/JEDNOTA/Jednota/g;
                            s/SUPERMARKET/supermarket/g; s/^Prodejna/prodejna/g; s/^Budova/budova/g;
                            s/^Bývalá/bývalá/g;')"
      type=""
      if [ $(echo "$name" |grep -c "mobilní pobočka") -gt 0 ]
      then
        name=$(echo $name |sed "s/ - mobilní pobočka//")
        type="Mobilní pobočka"
      fi

      addr_street=$(echo "$addr" |cut -d "," -f 1)
      addr_psc=$(echo "$addr" |cut -d "," -f 2 |sed "s/^ //")
      addr_city=$(echo "$addr" |cut -d "," -f 3 |sed "s/^ //")

      po=$(echo "$mo" |sed "s/,$//" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
      ut=$(echo "$tu" |sed "s/,$//" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
      st=$(echo "$we" |sed "s/,$//" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
      ct=$(echo "$th" |sed "s/,$//" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
      pa=$(echo "$fr" |sed "s/,$//" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
      so=$(echo "$sa" |sed "s/,$//" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
      ne=$(echo "$su" |sed "s/,$//" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")

      if [ "$po" != "closed" -a $(echo "$po" |grep -c "^[0-9]") -eq 0 ]; then po=""; fi
      if [ "$ut" != "closed" -a $(echo "$ut" |grep -c "^[0-9]") -eq 0 ]; then ut=""; fi
      if [ "$st" != "closed" -a $(echo "$st" |grep -c "^[0-9]") -eq 0 ]; then st=""; fi
      if [ "$ct" != "closed" -a $(echo "$ct" |grep -c "^[0-9]") -eq 0 ]; then ct=""; fi
      if [ "$pa" != "closed" -a $(echo "$pa" |grep -c "^[0-9]") -eq 0 ]; then pa=""; fi
      if [ "$so" != "closed" -a $(echo "$so" |grep -c "^[0-9]") -eq 0 ]; then so=""; fi
      if [ "$ne" != "closed" -a $(echo "$ne" |grep -c "^[0-9]") -eq 0 ]; then ne=""; fi

      oph="$(optimize_opening_hours_key)"
      write_text >> $text_file
      write_csv_line >> $csv_file
      if [ "$p_type" = "BANK" ]
      then
        write_osm_bank >> $osm_file
        write_geojson_bank >> $json_file
      else
        write_osm_atm >> $osm_file
        write_geojson_atm >> $json_file
      fi

  #     echo "lat=$lat"
  #     echo "lon=$lon"
  #     echo "name=$name"
  #     echo "type=$type"
  #     echo "addr_street=$addr_street"
  #     echo "addr_city=$addr_city"
  #     echo "addr_psc=$addr_psc"
  #     echo "po=$po"
  #     echo "ut=$ut"
  #     echo "st=$st"
  #     echo "ct=$ct"
  #     echo "pa=$pa"
  #     echo "so=$so"
  #     echo "ne=$ne"
  #     echo "oph=$oph"
  #     echo "-----"
  done < <(cat $work_csv)


}

## ============================================================================

# get list of duplicated coors

echo $(date "+%H:%M:%S")" - Looking for duplicated coors"
dupl_file=duplicated_coors
cat gps_poi_garmin.txt gps_ATM_poi_garmin.txt | egrep "@lat|@lon" |cut -d "=" -f 2 | paste - - -d"," |sort |uniq -d >$dupl_file
echo $(date "+%H:%M:%S")" - Found $(cat $dupl_file |wc -l) duplicated coors"

# fill array
declare -A dupl_coors
while IFS=$'\n' read LINE
do
  dupl_coors[$LINE]=0
done < <(cat $dupl_file)



# Bank
# define output files
work_csv=gps_poi_garmin.csv
text_file=ceska_sporitelna_pobocky.txt
csv_file=ceska_sporitelna_pobocky.csv
osm_file=ceska_sporitelna_pobocky.osm
json_file=ceska_sporitelna_pobocky.geojson

# init output files
echo '"Lat";"Lon";"Jméno";"Ulice";"Město";"PSČ";"Pondělí";"Úterý";"Středa";"Čtvrtek";"Pátek";"Sobota";"Neděle";"Poznámka"' > $csv_file

echo "<?xml version='1.0' encoding='UTF-8'?>" > $osm_file
echo "<osm version='0.6' upload='true' generator='shell'>" >> $osm_file

echo "{
    \"type\": \"FeatureCollection\",
    \"features\": [
" > $json_file

# node id for osm file
id=1

# set json delimiter
delim=""

echo $(date "+%H:%M:%S")" - Processing Banks"

process_file gps_poi_garmin.txt BANK

# finish osm file
echo "</osm>" >> $osm_file

# finish geojson file
echo "]" >> $json_file
echo "}" >> $json_file

# Atm
# define output files
text_file=ceska_sporitelna_bankomaty.txt
csv_file=ceska_sporitelna_bankomaty.csv
osm_file=ceska_sporitelna_bankomaty.osm
json_file=ceska_sporitelna_bankomaty.geojson

# init output files
echo '"Lat";"Lon";"Jméno";"Ulice";"Město";"PSČ";"Pondělí";"Úterý";"Středa";"Čtvrtek";"Pátek";"Sobota";"Neděle";"Poznámka"' > $csv_file

echo "<?xml version='1.0' encoding='UTF-8'?>" > $osm_file
echo "<osm version='0.6' upload='true' generator='shell'>" >> $osm_file

echo "{
    \"type\": \"FeatureCollection\",
    \"features\": [
" > $json_file

# node id for osm file
id=1000

# set json delimiter
delim=""

echo $(date "+%H:%M:%S")" - Processing ATMs"

process_file gps_ATM_poi_garmin.txt ATM

# finish osm file
echo "</osm>" >> $osm_file

# finish geojson file
echo "  ]" >> $json_file
echo "}" >> $json_file

echo $(date "+%H:%M:%S")" - Done"
