#!/usr/bin/env bash

weeklyDir="/home/marian/Dokumenty/WeeklyOSM-CZ"
baseDir=$(pwd)
outDir=${baseDir}
workDir=${baseDir}/work

mkdir -p "$workDir"

ls -1 ${weeklyDir} |tail -n 100 |head -n 99 |while read f
do
  echo "${weeklyDir}/$f";
  cd ${workDir}
  rm -f "*"

  # Split to parts
  csplit "${weeklyDir}/$f" '/^<h2/' '{*}'

  cd ${outDir}

  ls -1 $workDir |while read fp
  do
    outName=$(head -n 1 "${workDir}/${fp}" |cut -d ">" -f 2 |sed "s:</h2::" |tr " " "_")".txt"
    if [ "$outName" != "Plánované_události.txt" -a "$outName" != ".txt" ]
    then
      tail -n +2 "${workDir}/${fp}" |sed -e "/<ul>/d" -e "/<\/ul>/d" -e "s/\\t//g" -e "s/^ *//" >> "${outDir}/${outName}"
    fi
  done
done
