
echo "ref;lat;lon" > missing_coordinates.csv ; cat missing_coordinates.txt |tr '\t' ';' |egrep "^[0-9]+:[0-9]+;[0-9]+\.[0-9]+;[0-9]+\.[0-9]+" >>missing_coordinates.csv

echo
echo "$(wc -l missing_coordinates.csv)"
echo "For upload to postgress use:"
echo
echo "truncate table cp_geocoded_coors;"
echo "\\copy cp_geocoded_coors FROM '~/missing_coordinates.csv' DELIMITER ';' CSV"

