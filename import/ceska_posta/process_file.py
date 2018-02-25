#!/usr/bin/env python
"""Process Post Boxes dataset from Česká pošta for OSM import.

Reads input CSV file, parse it and generate tiles for POI-Importer,
GeoJson or sql file (used by statistics module)

More info on
 Github: https://github.com/mkyral/osm/tree/master/import/ceska_posta
 @talk-cz: https://lists.openstreetmap.org/listinfo/talk-cz
"""

import csv
import sys
import time

import pyproj

#https://github.com/frewsxcv/python-geojson
from geojson import Feature, Point, FeatureCollection
import json

# for distance calculation
from math import sin, cos, tan, sqrt, atan2, radians, pi, floor, log

__author__ = "Marián Kyral"
__copyright__ = "Copyright 2018"
__credits__ = ["Marián Kyral"]
__license__ = "GPLv3+"
__version__ = "1.0"
__maintainer__ = "Marián Kyral"
__email__ = "mkyral@email.cz"
__status__ = "Production"

# configuration
osm_precision = 7
bbox = {'min': {'lat': 48.55, 'lon': 12.09}, 'max': {'lat': 51.06, 'lon': 18.87}}

# where to store POI-Importer tiles
tiles_config="tiles/dataset.json"
tiles_dir="tiles/data"

# counters
line_counter = 0
missing_count = 0
error_count = 0

boxes = {}
geocoded_coors = {}
osm_coors = {}

# Init projection
inProj = pyproj.Proj(init='epsg:5514', proj='krovak', ellps='bessel', towgs84='570.8,85.7,462.8,4.998,1.587,5.261,3.56')
outProj = pyproj.Proj(init='epsg:4326')


# compute distance between two points
def get_distance(p1, p2):

    R = 6373.0

    lat1 = radians(p1['lat'])
    lon1 = radians(p1['lon'])
    lat2 = radians(p2['lat'])
    lon2 = radians(p2['lon'])

    dlon = lon2 - lon1
    dlat = lat2 - lat1

    a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return (R * c)

# format distance value - add unit
def format_distance(distance):

    if (distance > 1):
        return("%s km" % round(distance, 1))
    else:
        distance = distance * 1000
        if (distance > 1):
            return("%s m" % round(distance, 2))
        else:
            distance = distance * 1000
            return("%s cm" % round(distance, 2))

# Get tile xy coors
def latlonToTilenumber(zoom, lat, lon):
    n = (2 ** zoom);
    lat_rad = lat * pi / 180;
    return ({
            "x": floor(n * ((lon + 180) / 360)),
            "y": floor(n * (1 - (log(tan(lat_rad) + 1/cos(lat_rad)) / pi)) / 2) })

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

def load_corrections():
    global geocoded_coors
    global osm_coors
    global osm_precision

    # Load geocoded coors
    try:
        with open('missing_coordinates.csv', newline='') as csvfile:
            csvreader = csv.DictReader(csvfile, delimiter=';')
            for row in csvreader:
                latlon = {}
                latlon['lat'] = round(float(row['lat']), osm_precision)
                latlon['lon'] = round(float(row['lon']), osm_precision)
                geocoded_coors[row['ref']] = latlon
    except Exception as error:
        print(error)
        print('Can\'t read file "missing_coordinates.csv", skipping it')

    # Load geocoded coors
    try:
        with open('osm_coors.csv', newline='') as csvfile:
            csvreader = csv.DictReader(csvfile, delimiter=';')
            for row in csvreader:
                latlon = {}
                latlon['lat'] = round(float(row['lat']), osm_precision)
                latlon['lon'] = round(float(row['lon']), osm_precision)
                osm_coors[row['ref']] = latlon
    except Exception as error:
        print(error)
        print('Can\'t read file "osm_coors.csv", skipping it')

# ------------
#     Main
# ------------

# Read input parameters
program_name = sys.argv[0]
arguments = sys.argv[1:]

if (len(arguments) < 2):
    print("Usage: %s IN_CSV_FILE tiles" % (program_name))
    print("   or  %s IN_CSV_FILE geojson|sql OUT_FILE_PATTERN" % (program_name))
    exit(1)

infile = arguments[0]
outtype = arguments[1].lower()
if (outtype != 'geojson' and outtype != 'tiles' and outtype != 'sql'):
    print("Unknown output type: %s." % (outtype))
    exit(1)

if (len(arguments) > 2):
    outfile = arguments[2]
else:
    outfile='N/A'

# Extract source file date id
fname=infile.split(".")[0].split("_")
inid=fname[len(fname)-1]

print("Infile: %s; source: %s; outfile: %s; outtype: %s" % (infile, inid, outfile, outtype))
# Load files with correction
load_corrections()

if outtype == "tiles":
    # Load dataset config file
    try:
        with open(tiles_config) as cfg:
            dataset = json.load(cfg)
            print("Zoom: %s" % (dataset['zoom']))
    except Exception as error:
        print('Error during loading of dataset configuration file!')
        print(error)
        exit(1)

print("\nLoading CSV file...")
start_time = time.time()
try:
    with open(infile, newline='', encoding='cp1250') as csvfile:
        csvreader = csv.DictReader(csvfile, delimiter=';')
        for row in csvreader:
            line_counter += 1
            box = {}
            krovak = {}
            wgs84 = {}
            collection_times = {}

            box['ref'] = ("%s:%s" % (row['psc'], row['cis_schranky']))

            if len(row) != 12:
                    error_count += 1
                    print(" >> Warning: too many columns (%s) for ref: %s at line %s" % (len(row), box['ref'], (line_counter+1)))

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

            days = row['omezeni'].split()[0]
            #.replace('1','1Mo').replace('2','2Tu').replace('3','3We').replace('4','4Th').replace('5','5Fr').replace('6','6Sa').replace('7','7Su')

            collection_times[days] = row['cas']
            box['collection_times'] = collection_times

            merge_box(box)
except Exception as error:
    print('Error :-(')
    print(error)
    exit(1)

print ("...CSV file loaded in %ss" % (round(time.time() - start_time, 2)))
# generate geojson
start_time = time.time()
if (outtype == 'geojson' or outtype == 'tiles'):

    if outtype == 'tiles':
        print("\nGenerating Tiles...")
    else:
        print("\nGenerating GeoJson file...")

    files = {}
    coll = []

    geojson_file = "%s.%s" % (outfile, 'geojson')

    if (outtype == 'geojson'):
        files[geojson_file] = coll

    for k in sorted(boxes.keys()):
        box = boxes[k]

        if (('wgs84' in box and 'lat' in box['wgs84']) or k in geocoded_coors):
            props = {}
            props['amenity'] = 'post_box'
            props['ref'] = k
            props['operator'] = 'Česká pošta, s.p.'

            # Shift coordinates according to OSM or geocoded coors
            coors_shift=''
            if (k in osm_coors):
                coors_shift = "<p style='text-align: center'><u>Souřadnice převzaty z OSM!</u>"
                if ('wgs84' in box and 'lat' in box['wgs84']):
                    dist = get_distance(box['wgs84'], osm_coors[k])
                    if (dist < 1 ):
                        coors_shift = ("%s<br>Posunuto o %s" % (coors_shift, format_distance(dist)))

                if not coors_shift:
                    coors_shift = ("%s%s" % (coors_shift, "</p>"))

                if (dist < 1 ):
                    box['wgs84:orig'] = {}

                    if ('wgs84' in box and 'lat' in box['wgs84']):
                        box['wgs84:orig'] = box['wgs84']
                    box['wgs84'] = osm_coors[k]

            if (k in geocoded_coors and not ('wgs84' in box and 'lat' in box['wgs84'])):
                coors_shift = "<p style='color:red; text-align:center'><b>POZOR:</b> Souřadnice jsou pouze <u>orientační</u>!<br>Přesné umístění nutno dohledat dle poznámky!</p>"

                box['wgs84:orig'] = {}

                if ('wgs84' in box and 'lat' in box['wgs84']):
                    box['wgs84:orig'] = box['wgs84']
                box['wgs84'] = geocoded_coors[k]

            if (box['address']):
                props['_note'] = ('<br><b>Poznámka:</b> %s <br><b>Adresa:</b> %s %s' % (box['place_desc'], box['address'], coors_shift))
            else:
                props['_note'] = ('<br><b>Poznámka:</b> %s <br><b>Adresa:</b> %s; %s; %s %s' % (box['place_desc'], box['district'], box['village'], box['suburb'], coors_shift))

            if (box['collection_times']):
                ct = []
                for k in sorted(box['collection_times'].keys()):
                    key = k.replace('1','Mo').replace('2','Tu').replace('3','We').replace('4','Th').replace('5','Fr').replace('6','Sa').replace('7','Su')
                    ct.append('%s %s' % (key, box['collection_times'][k]))
                props['collection_times'] = '; '.join(ct)

            feature = Feature(geometry=Point((box['wgs84']['lon'], box['wgs84']['lat'])), properties=props)

            if outtype != 'tiles':
                files[geojson_file].append(feature)
            else:
                tile = latlonToTilenumber(dataset['zoom'], box['wgs84']['lat'], box['wgs84']['lon'])
                filename = "%s/%s_%s.json" % (tiles_dir, tile['x'], tile['y'])
                if filename not in files:
                    coll = []
                    files[filename] = coll
                files[filename].append(feature)

    # write to file
    try:
        for k in sorted(files.keys()):
            feature_collection = FeatureCollection(files[k])

            with open(k, encoding='utf-8', mode='w+') as geojsonfile:
                geojsonfile.write(json.dumps(feature_collection, ensure_ascii=False, indent=2, sort_keys=True))

    except Exception as error:
        print('Error :-(')
        print(error)
        exit(1)

    print ("...JSON file generated in %ss" % (round(time.time() - start_time, 2)))


if (outtype == 'sql'):
    start_time = time.time()
# Prepare inserts into database
    print("\nGenerating sql...")
    try:
        with open("%s.%s" % (outfile, 'sql'), encoding='utf-8', mode='w+') as sqlfile:
            sqlfile.write("truncate table cp_post_boxes_upload;\n")
            sqlfile.write("\n")
            for k in boxes:
                box = boxes[k]
                data = {}

                data['ref'] = box['ref']
                data['psc'] = box['psc']
                data['id'] = box['id']

                if ('wgs84' in box and 'lat' in box['wgs84']):
                    data['x'] = box['krovak']['x']
                    data['y'] = box['krovak']['y']
                    data['lat'] = box['wgs84']['lat']
                    data['lon'] = box['wgs84']['lon']
                    data['updated_lat'] = 'null'
                    data['updated_lon'] = 'null'
                else:
                    data['x'] = 'null'
                    data['y'] = 'null'
                    data['lat'] = 'null'
                    data['lon'] = 'null'
                    data['updated_lat'] = 'null'
                    data['updated_lon'] = 'null'

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
                        key = k.replace('1','Mo').replace('2','Tu').replace('3','We').replace('4','Th').replace('5','Fr').replace('6','Sa').replace('7','Su')
                        ct.append('%s %s' % (key, box['collection_times'][k]))
                    data['collection_times'] = '; '.join(ct)
                else:
                    data['collection_times'] = 'null'

                sqlfile.write("insert into cp_post_boxes_upload (ref, psc, id, x, y, lat, lon, updated_lat, updated_lon, address, place, suburb, village, district, collection_times, source) values ( '%s', %s, %s, %s, %s, %s, %s,  %s, %s, '%s', '%s', '%s', '%s', '%s', '%s', 'CP:%s' );\n" %
                (data['ref'], data['psc'], data['id'], data['x'], data['y'], data['lat'], data['lon'], data['updated_lat'], data['updated_lon'], data['address'], data['place'], data['suburb'], data['village'], data['district'], data['collection_times'], inid))

    except Exception as error:
        print('Error :-(')
        print(error)
        exit(1)

    print ("...SQL file generated in %ss" % (round(time.time() - start_time, 2)))

# some final stats
print("\n-----------------------------------------------------")
print("Total lines: %d, missing coors: %d, errors: %s" % (line_counter, missing_count, error_count))
print('Boxes: %d' % (len(boxes)))
print("-----------------------------------------------------")

