#!/usr/bin/env python


import sys
import csv
import pyproj

#https://github.com/frewsxcv/python-geojson
from geojson import Feature, Point, FeatureCollection
import json

# configuration
osm_precision = 7
bbox = {'min': {'lat': 48.55, 'lon': 12.09}, 'max': {'lat': 51.06, 'lon': 18.87}}

# counters
ln_count = 0
missing_count = 0

boxes = {}

# Init projection
inProj = pyproj.Proj(init='epsg:5514', proj='krovak', ellps='bessel', towgs84='570.8,85.7,462.8,4.998,1.587,5.261,3.56')
outProj = pyproj.Proj(init='epsg:4326')


# Check coors whether are in bbox
def check_bbox(coors):
    global bbox
    if ( coors['lat'] >= bbox['min']['lat'] and coors['lat'] <= bbox['max']['lat'] and
         coors['lon'] >= bbox['min']['lon'] and coors['lon'] <= bbox['max']['lon']):
        return True
    return False

# merge box into list of boxes
def merge_box(box):
    global boxes

    if (box['ref'] in boxes):
        #print("%s: Merging key" % (box['ref']))
        collection_times = box['collection_times']
        key = list(collection_times.keys())[0]

        if (key in boxes[box['ref']]['collection_times']):
            boxes[box['ref']]['collection_times'][key] = ",".join([boxes[box['ref']]['collection_times'][key],collection_times[key]])
        else:
            boxes[box['ref']]['collection_times'][key] = collection_times[key]

        #boxes[box['ref']]['collection_times'] = ",".join([boxes[box['ref']]['collection_times'], box['collection_times']])
        #print("%s: %s " % (box['ref'],boxes[box['ref']]['collection_times']))
    else:
        boxes[box['ref']] = box

# ------------
#     Main
# ------------

# Read input parameters
program_name = sys.argv[0]
arguments = sys.argv[1:]

if (len(arguments) != 2):
    print("Usage: %s IN_CSV_FILE OUT_GEOJSON_FILE" % (program_name))
    exit(1)

infile = arguments[0]
outfile = arguments[1]

print("Infile: %s; outfile: %s" % (infile, outfile))

try:
    with open(infile, newline='', encoding='cp1250') as csvfile:
        csvreader = csv.DictReader(csvfile, delimiter=';')
        for row in csvreader:
            ln_count += 1
            box = {}
            krovak = {}
            wgs84 = {}
            collection_times = {}

            box['ref'] = ("%s:%s" % (row['psc'], row['cis_schranky']))

            krovak['x'],krovak['y'] = row['sour_x'],row['sour_y']
            box['krovak'] = krovak

            if krovak['x'] == "":
                missing_count += 1
                #print ("%s: Missing coordinates" % (box['ref']))
            else :
                lon, lat = pyproj.transform(inProj,outProj,-float(krovak['y']), -float(krovak['x']))

                wgs84['lon'] = round(lon, osm_precision)
                wgs84['lat'] = round(lat, osm_precision)
                if (check_bbox(wgs84)):
                    box['wgs84'] = wgs84
                else:
                    print("Coordinates %s, %s out of bbox" % (wgs84['lat'], wgs84['lon']))

            box['psc'] = row['psc']
            box['id'] = row['cis_schranky']
            box['address'] = row['adresa']
            box['place_desc'] = row['misto_popis']
            box['suburb'] = row['cast_obce']
            box['village'] = row['obec']
            box['district'] = row['okres']

            days = row['omezeni'].split()[0].replace('1','1Mo').replace('2','2Tu').replace('3','3We').replace('4','4Th').replace('5','5Fr').replace('6','6Sa').replace('7','7Su')

            collection_times[days] = row['cas']
            box['collection_times'] = collection_times

            merge_box(box)
except Exception as error:
    print('Error :-(')
    print(error)
    exit(1)

# generate geojson
print("Generating GeoJson")

coll = []

for k in boxes:
    box = boxes[k]

    if ('wgs84' in box and 'lat' in box['wgs84']):
        props = {}
        props['amenity'] = 'post_box'
        props['ref'] = k
        props['operator'] = 'Česká pošta, s.p.'

        if (box['address']):
            props['_note'] = ('<br><b>Poznámka:</b> %s <br><b>Adresa:</b> %s' % (box['place_desc'], box['address']))
        else:
            props['_note'] = ('<br><b>Poznámka:</b> %s <br><b>Adresa:</b> %s; %s; %s' % (box['place_desc'], box['district'], box['village'], box['suburb']))

        if (box['collection_times']):
            ct = []
            for k in sorted(box['collection_times'].keys()):
                key = k.replace('1Mo','Mo').replace('2Tu','Tu').replace('3We','We').replace('4Th','Th').replace('5Fr','Fr').replace('6Sa','Sa').replace('7Su','Su')
                ct.append('%s %s' % (key, box['collection_times'][k]))
            props['collection_times'] = '; '.join(ct)

        feature = Feature(geometry=Point((box['wgs84']['lon'], box['wgs84']['lat'])), properties=props)
        coll.append(feature)

feature_collection = FeatureCollection(coll)

# write to file
try:
    with open(outfile, encoding='utf-8', mode='w+') as geojsonfile:
        geojsonfile.write(json.dumps(feature_collection, ensure_ascii=False, indent=2))
except Exception as error:
    print('Error :-(')
    print(error)
    exit(1)

# some final stats
print("Total lines: %d, missing coors: %d" % (ln_count, missing_count))
print('Boxes: %d' % (len(boxes)))


# Prepare inserts into database
print("Generating sql")
try:
    with open('inserts.sql', encoding='utf-8', mode='w+') as sqlfile:
        for k in boxes:
            box = boxes[k]
            data = {}

            data['ref'] = box['ref']
            data['psc'] = box['psc']
            data['id'] = box['id']

            if ('wgs84' in box and 'lat' in box['wgs84']):
                data['x'] = box['krovak']['x']
                data['y'] = box['krovak']['x']
                data['lat'] = box['wgs84']['lat']
                data['lon'] = box['wgs84']['lon']
            else:
                data['x'] = 'null'
                data['y'] = 'null'
                data['lat'] = 'null'
                data['lon'] = 'null'

            if ('address' in box):
                data['address'] = box['address']
            else:
                data['address'] = ''

            data['place'] = box['place_desc']
            data['suburb'] = box['suburb']
            data['village'] = box['village']
            data['district'] = box['district']

            if ('collection_times' in box):
                ct = []
                for k in sorted(box['collection_times'].keys()):
                    key = k.replace('1Mo','Mo').replace('2Tu','Tu').replace('3We','We').replace('4Th','Th').replace('5Fr','Fr').replace('6Sa','Sa').replace('7Su','Su')
                    ct.append('%s %s' % (key, box['collection_times'][k]))
                data['collection_times'] = '; '.join(ct)
            else:
                data['collection_times'] = 'null'

            sqlfile.write("insert into cp_post_boxes (ref, psc, id, x, y, lat, lon, address, place, suburb, village, district, collection_times, create_date, source) values ( '%s', %s, %s, %s, %s, %s, %s, '%s', '%s', '%s', '%s', '%s', '%s', current_timestamp, 'CP:201802' );\n" %
            (data['ref'], data['psc'], data['id'], data['x'], data['y'], data['lat'], data['lon'], data['address'], data['place'], data['suburb'], data['village'], data['district'], data['collection_times']))

except Exception as error:
    print('Error :-(')
    print(error)
    exit(1)
