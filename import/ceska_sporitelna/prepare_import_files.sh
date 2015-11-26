#!/bin/bash

[ ! -e tmp ] && mkdir tmp
cd tmp
# wget "http://www.csas.cz/banka/content/inet/internet/cs/gps_poi_garmin.xml"
#
# xml2 < gps_poi_garmin.xml > gps_poi_garmin.txt
#
# wget "http://www.csas.cz/banka/content/inet/internet/cs/gps_ATM_poi_garmin.xml"
#
# xml2 < gps_ATM_poi_garmin.xml > gps_ATM_poi_garmin.txt

# Bank
# define output files
text_file=ceska_sporitelna_pobocky.txt
csv_file=ceska_sporitelna_pobocky.csv
osm_file=ceska_sporitelna_pobocky.osm

# init output files
echo '"Lat";"Lon";"Jméno";"Ulice";"Město";"PSČ";"Pondělí";"Úterý";"Středa";"Čtvrtek";"Pátek";"Sobota";"Neděle";"Poznámka"' > $csv_file

echo "<?xml version='1.0' encoding='UTF-8'?>" > $osm_file
echo "<osm version='0.6' upload='true' generator='shell'>" >> $osm_file

# node id for osm file
id=1

# Convert opening hours to OSM format
optimize_opening_hours_key()
{
  # initialize variables

  declare -a oh_days=()
  declare -a opening_hours=()
  declare -a data=("$po" "$ut" "$st" "$ct" "$pa" "$so" "$ne");
  declare -a days=("Mo" "Tu" "We" "Th" "Fr" "Sa" "Su")

  # go through days and group days with the same opening_hours
  for idx in $(seq 0 $((${#data[@]}-1)))
  do
#     echo "$idx: ${data[$idx]}"
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
  local oph="$(optimize_opening_hours_key)"
  echo "<node id='-$((id++))' action='modify' visible='true' lat='$lat' lon='$lon'>"
  echo "  <tag k='amenity' v='bank' />"
  echo "  <tag k='bic' v='GIBACZPX' />"
  echo "  <tag k='brand' v='Česká spořitelna' />"
  echo "  <tag k='name' v='Česká spořitelna, $name' />"
  if [ "$oph" ]; then echo "  <tag k='opening_hours' v='$oph' />"; fi
  echo "  <tag k='operator' v='Česká spořitelna' />"
  if [ "$type" ]; then echo "  <tag k='description' v='$type' />"; fi
  echo "  <tag k='source' v='ceska_sporitelna_gpx' />"
  echo "</node>"
}

write_osm_atm()
{
  local oph="$(optimize_opening_hours_key)"
  echo "<node id='-$((id++))' action='modify' visible='true' lat='$lat' lon='$lon'>"
  echo "  <tag k='amenity' v='atm' />"
  echo "  <tag k='network' v='Česká spořitelna' />"
  echo "  <tag k='name' v='$name' />"|sed "s/&/&amp;/g"
  if [ "$oph" ]; then echo "  <tag k='opening_hours' v='$oph' />"; fi
  echo "  <tag k='operator' v='Česká spořitelna' />"
  if [ "$type" ]; then echo "  <tag k='description' v='$type' />"; fi
  echo "  <tag k='source' v='ceska_sporitelna_gpx' />"
  echo "</node>"
}

echo $(date "+%H:%M:%S")" - Processing Banks"
cat gps_poi_garmin.txt |egrep "/gpx/wpt/@|/gpx/wpt/name|/gpx/wpt/cmt" |sed "s|/gpx/wpt/||" |while read line
do
  key=$(echo "$line" |cut -d "=" -f 1)
  val=$(echo "$line" |cut -d "=" -f 2)
#   echo "Key= $key"
#   echo "Val= $val"

  if [ "$key" = "@lat" ]
  then
    lat=$val
    continue
  elif [ "$key" = "@lon" ]
  then
    lon=$val
    continue
  elif [ "$key" = "name" ]
  then
    name="$(echo $val |sed 's/^\(.\)/\U\1/g; s/ALBERT/Albert/g; s/BILLA/Billa/g; s/BIG/Big/g; s/TESCO/Tesco/g;
                            s/KAUFLAND/Kaufland/g; s/GLOBUS/Globus/g; s/HORNBACH/Hornbach/g; s/LIDL/Lidl/g;
                            s/PENNY MARKET/Penny Market/g; s/TERNO/Terno/g; s/COOP/Coop/g; s/JEDNOTA/Jednota/g;
                            s/SUPERMARKET/supermarket/g; s/^Prodejna/prodejna/g; s/^Budova/budova/g;
                            s/^Bývalá/bývalá/g;') "
    type=""
    if [ $(echo "$name" |grep -c "mobilní pobočka") -gt 0 ]
    then
      name=$(echo $name |sed "s/ - mobilní pobočka//")
      type="Mobilní pobočka"
    fi
    continue
  elif [ "$key" = "cmt" ]
  then
    addr=$(echo "$val" |sed "s/^\(.*\) Provozní doba: .*$/\1/")
    addr_street=$(echo "$addr" |cut -d "," -f 1)
    addr_psc=$(echo "$addr" |cut -d "," -f 2)
    addr_city=$(echo "$addr" |cut -d "," -f 3)

    po=$(echo "$val" |sed "s/^.* Po: \(.*\), Út: .*$/\1/" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    ut=$(echo "$val" |sed "s/^.* Út: \(.*\), St: .*$/\1/" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    st=$(echo "$val" |sed "s/^.* St: \(.*\), Čt: .*$/\1/" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    ct=$(echo "$val" |sed "s/^.* Čt: \(.*\), Pá: .*$/\1/" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    pa=$(echo "$val" |sed "s/^.* Pá: \(.*\), So: .*$/\1/" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    so=$(echo "$val" |sed "s/^.* So: \(.*\), Ne: .*$/\1/" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    ne=$(echo "$val" |sed "s/^.* Ne: \(.*\)$/\1/" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")

    if [ "$po" != "closed" -a $(echo "$po" |grep -c "^[0-9]") -eq 0 ]; then po=""; fi
    if [ "$ut" != "closed" -a $(echo "$ut" |grep -c "^[0-9]") -eq 0 ]; then ut=""; fi
    if [ "$st" != "closed" -a $(echo "$st" |grep -c "^[0-9]") -eq 0 ]; then st=""; fi
    if [ "$ct" != "closed" -a $(echo "$ct" |grep -c "^[0-9]") -eq 0 ]; then ct=""; fi
    if [ "$pa" != "closed" -a $(echo "$pa" |grep -c "^[0-9]") -eq 0 ]; then pa=""; fi
    if [ "$so" != "closed" -a $(echo "$so" |grep -c "^[0-9]") -eq 0 ]; then so=""; fi
    if [ "$ne" != "closed" -a $(echo "$ne" |grep -c "^[0-9]") -eq 0 ]; then ne=""; fi

    write_text >> $text_file
    write_csv_line >> $csv_file
    write_osm_bank >> $osm_file
  fi
done

# finish osm file
echo "</osm>" >> $osm_file


# Atm
# define output files
text_file=ceska_sporitelna_bankomaty.txt
csv_file=ceska_sporitelna_bankomaty.csv
osm_file=ceska_sporitelna_bankomaty.osm

# init output files
echo '"Lat";"Lon";"Jméno";"Ulice";"Město";"PSČ";"Pondělí";"Úterý";"Středa";"Čtvrtek";"Pátek";"Sobota";"Neděle";"Poznámka"' > $csv_file

echo "<?xml version='1.0' encoding='UTF-8'?>" > $osm_file
echo "<osm version='0.6' upload='true' generator='shell'>" >> $osm_file

# node id for osm file
id=1000

echo $(date "+%H:%M:%S")" - Processing ATMs"
cat gps_ATM_poi_garmin.txt |egrep "/gpx/wpt/@|/gpx/wpt/name|/gpx/wpt/cmt" |sed "s|/gpx/wpt/||" |while read line
do
  key=$(echo "$line" |cut -d "=" -f 1)
  val=$(echo "$line" |cut -d "=" -f 2)
#   echo "Key= $key"
#   echo "Val= $val"

  if [ "$key" = "@lat" ]
  then
    lat=$val
    continue
  elif [ "$key" = "@lon" ]
  then
    lon=$val
    continue
  elif [ "$key" = "name" ]
  then
    name="$(echo $val |sed 's/^\(.\)/\U\1/g; s/ALBERT/Albert/g; s/BILLA/Billa/g; s/BIG/Big/g; s/TESCO/Tesco/g;
                            s/KAUFLAND/Kaufland/g; s/GLOBUS/Globus/g; s/HORNBACH/Hornbach/g; s/LIDL/Lidl/g;
                            s/PENNY MARKET/Penny Market/g; s/TERNO/Terno/g; s/COOP/Coop/g; s/JEDNOTA/Jednota/g;
                            s/SUPERMARKET/supermarket/g; s/^Prodejna/prodejna/g; s/^Budova/budova/g;
                            s/^Bývalá/bývalá/g;') "
    type=""
    if [ $(echo "$name" |grep -c "mobilní pobočka") -gt 0 ]
    then
      name=$(echo $name |sed "s/ - mobilní pobočka//")
      type="Mobilní pobočka"
    fi
    continue
  elif [ "$key" = "cmt" ]
  then
    addr=$(echo "$val" |sed "s/^\(.*\) Provozní doba: .*$/\1/")
    addr_street=$(echo "$addr" |cut -d "," -f 1)
    addr_psc=$(echo "$addr" |cut -d "," -f 2)
    addr_city=$(echo "$addr" |cut -d "," -f 3)

    po=$(echo "$val" |sed -n "s/^.* Po: \(.*\), Út: .*$/\1/p" |sed "s/ - /-/g" | sed "s/zavřeno/closed/")
    ut=$(echo "$val" |sed -n "s/^.* Út: \(.*\), St: .*$/\1/p" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    st=$(echo "$val" |sed -n "s/^.* St: \(.*\), Čt: .*$/\1/p" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    ct=$(echo "$val" |sed -n "s/^.* Čt: \(.*\), Pá: .*$/\1/p" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    pa=$(echo "$val" |sed -n "s/^.* Pá: \(.*\), So: .*$/\1/p" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    so=$(echo "$val" |sed -n "s/^.* So: \(.*\), Ne: .*$/\1/p" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")
    ne=$(echo "$val" |sed -n "s/^.* Ne: \(.*\)$/\1/p" |sed "s/ - /-/g"| sed "s/zavřeno/closed/")

#     if [ "$po" != "closed" -a $(echo "$po" |grep -c "^[0-9][0-9]:") -eq 0 ]; then po=""; fi
#     if [ "$ut" != "closed" -a $(echo "$ut" |grep -c "^[0-9][0-9]:") -eq 0 ]; then ut=""; fi
#     if [ "$st" != "closed" -a $(echo "$st" |grep -c "^[0-9][0-9]:") -eq 0 ]; then st=""; fi
#     if [ "$ct" != "closed" -a $(echo "$ct" |grep -c "^[0-9][0-9]:") -eq 0 ]; then ct=""; fi
#     if [ "$pa" != "closed" -a $(echo "$pa" |grep -c "^[0-9][0-9]:") -eq 0 ]; then pa=""; fi
#     if [ "$so" != "closed" -a $(echo "$so" |grep -c "^[0-9][0-9]:") -eq 0 ]; then so=""; fi
#     if [ "$ne" != "closed" -a $(echo "$ne" |grep -c "^[0-9][0-9]:") -eq 0 ]; then ne=""; fi

    write_text >> $text_file
    write_csv_line >> $csv_file
    write_osm_atm >> $osm_file
  fi
done

# finish osm file
echo "</osm>" >> $osm_file

echo $(date "+%H:%M:%S")" - Done"
