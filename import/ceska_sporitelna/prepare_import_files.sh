#!/bin/bash

# mkdir tmp
# cd tmp
# wget "http://www.csas.cz/banka/content/inet/internet/cs/gps_poi_garmin.xml"
# 
# xml2 < gps_poi_garmin.xml > gps_poi_garmin.txt

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
    ret="${ret}$(echo ${oh_days[$oh_idx]} |sed 's/,$//') ${opening_hours[$oh_idx]};"
  done

  echo "$(echo $ret |sed 's/;$//')"
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

write_osm()
{
  echo "<node id='-$((id++))' action='modify' visible='true' lat='$lat' lon='$lon'>"
  echo "  <tag k='amenity' v='bank' />"
  echo "  <tag k='bic' v='GIBACZPX' />"
  echo "  <tag k='brand' v='Česká spořitelna' />"
  echo "  <tag k='name' v='Česká spořitelna, $name' />"
  echo "  <tag k='opening_hours' v='$(optimize_opening_hours_key)' />"
  echo "  <tag k='operator' v='Česká spořitelna a.s.' />"
  if [ "$type" ]; then echo "  <tag k='description' v='$type' />"; fi
  echo "  <tag k='source' v='ceska_sporitelna_gpx' />"
  echo "</node>"
}

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
    name="$val"
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
    
    po=$(echo "$val" |sed "s/^.* Po: \(.*\), Út: .*$/\1/" |tr -d " "| sed "s/zavřeno/closed/")
    ut=$(echo "$val" |sed "s/^.* Út: \(.*\), St: .*$/\1/" |tr -d " "| sed "s/zavřeno/closed/")
    st=$(echo "$val" |sed "s/^.* St: \(.*\), Čt: .*$/\1/" |tr -d " "| sed "s/zavřeno/closed/")
    ct=$(echo "$val" |sed "s/^.* Čt: \(.*\), Pá: .*$/\1/" |tr -d " "| sed "s/zavřeno/closed/")
    pa=$(echo "$val" |sed "s/^.* Pá: \(.*\), So: .*$/\1/" |tr -d " "| sed "s/zavřeno/closed/")
    so=$(echo "$val" |sed "s/^.* So: \(.*\), Ne: .*$/\1/" |tr -d " "| sed "s/zavřeno/closed/")
    ne=$(echo "$val" |sed "s/^.* Ne: \(.*\)$/\1/" |tr -d " "| sed "s/zavřeno/closed/")

    write_text >> $text_file
    write_csv_line >> $csv_file
    write_osm >> $osm_file
  fi
done

# finish osm file
echo "</osm>" >> $osm_file
