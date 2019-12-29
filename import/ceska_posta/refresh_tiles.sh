#/usr/bin/env bash

cd ~/importy/schranky

# download updated coors

scp marian@poloha.net:~/exports/osm_coors.csv ./

# generate tiles
python3 process_file.py POST_SCHRANKY_latest.csv tiles

# upload changed tiles
cd tiles/data

if [ $(git status |grep -c "Changes not staged for commit:") -gt 0 ]
then
    git add *
    git commit -m "Updated tiles: $(date '+%d.%m.%Y')"
    git push -u origin master
    ( 
        echo "cd POI-Importer-testing/datasets/Czech-ceska-posta-schranky/data"
        echo "bin"
        git diff-tree --name-status -r HEAD..HEAD^ | while read STATUS FILE; 
        do 
            echo "put $(basename $FILE)"; 
        done
        echo "bye"
    ) | ftp -i -v ftp.kyralovi.cz

else
    echo "There are no changes for upload"
fi

