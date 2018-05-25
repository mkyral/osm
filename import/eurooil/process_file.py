#!/usr/bin/env python
"""Process EuroOil data for OSM import.

Reads input json file, convert it and generate tiles for POI-Importer

More info on
 Github: https://github.com/mkyral/osm/tree/master/import/EuroOil
 @talk-cz: https://lists.openstreetmap.org/listinfo/talk-cz
"""

import sys
import time
import re

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

# ------------
#     Main
# ------------

# Read input parameters
program_name = sys.argv[0]
arguments = sys.argv[1:]

if (len(arguments) < 1):
    print("Usage: %s IN_JSON_FILE" % (program_name))
    exit(1)

infile = arguments[0]

print("Infile: %s" % (infile))

# Load dataset config file
try:
    with open(tiles_config) as cfg:
        dataset = json.load(cfg)
        print("Zoom: %s" % (dataset['zoom']))
except Exception as error:
    print('Error during loading of dataset configuration file!')
    print(error)
    exit(1)

print("\nLoading JSON file...")
start_time = time.time()
try:
    with open(infile) as jsonfile:
        stations = json.load(jsonfile)
except Exception as error:
    print('Error :-(')
    print(error)
    exit(1)

print ("...JSON file loaded in %ss" % (round(time.time() - start_time, 2)))
# generate geojson
start_time = time.time()
print("\nGenerating Tiles...")

files = {}
coll = []

for s in stations:

    props = {}
    props['amenity'] = 'fuel'
    props['ref'] = s['cislo']
    props['name'] = ("EuroOil %s" % s['jmeno'])
    props['operator'] = 'Čepro, a.s.'
    props['brand'] = 'EuroOil'
    props['source'] = 'cepro_website'

    if s['optdiesel'] == 1 or s['optdieselplus'] == 1:
        props['fuel:diesel'] = 'yes'

    if s['ekodiesel'] == 1:
        props['fuel:biodiesel'] = 'yes'

    if s['adblue'] == 1:
        props['fuel:adblue'] = 'yes'

    if s['cng'] == 1:
        props['fuel:cng'] = 'yes'

    if s['lpg'] == 1:
        props['fuel:lpg'] = 'yes'

    if s['e85'] == 1:
        props['fuel:e85'] = 'yes'

    if s['ba91s'] == 1:
        props['fuel:octane_91'] = 'yes'

    if s['ba95n'] == 1 or s['opt95e'] == 1:
        props['fuel:octane_95'] = 'yes'

    if s['ba98'] == 1:
        props['fuel:octane_98'] = 'yes'

    if s['wifi'] == 1:
        props['internet_access'] = 'wlan'
        props['internet_access:fee'] = 'no'

    if s['myci_box'] == 1 or s['myci_linka'] == 1:
        props['car_wash'] = 'yes'

    if s['pb'] == 1:
        props['shop'] = 'gas'

    # Openning hours
    isTimePeriod = re.compile('.*:[0-9]+-[0-9]+:.*')
    startsByNumber = re.compile('.*:[0-9]+-[0-9]+:.*')
    hasMissingNumber = re.compile('^[0-9]:.*')

    weekDays = ('Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su')
    opening_hours=[];

    for oh in s['provozni_doba'].replace(" -", "-").replace("- ", "-").replace('Po-Pá', 'Mo-Fr').replace('So-Ne', 'Sa-Su').split(","):
        o = oh.strip()

        if o == 'NONSTOP':
            opening_hours.append('24/7')
            break

        if o == 'rekonstrukce' or o == 'zavřeno':
            opening_hours.append('closed')
            break

        if o[0:2] == 'L:':
            print("[Opening hours] Unknown string: %s" % (o))
        break

        if isTimePeriod.match(o):
            if startsByNumber.match(o):
                if hasMissingNumber.match(o):
                    opening_hours.append('0%s' % (o)[0:10])
                else:
                    opening_hours.append(o)
            continue

        if isTimePeriod.match(o) and o[0:2] in weekDays:
            # Add missing leading zero
            opening_hours.append(re.sub(' ([0-9]:)', r' 0\1', o))

        print("[Opening hours] Unknown string: %s" % (o))

    if len(opening_hours) > 0:
        props['opening_hours'] =';'.join(opening_hours)

        #'jmeno': 'Bělčice',
        #'nm_bez_spd': 0,
        #'cislo_popisne': '298',
        #'obec': 'Bělčice ',
        #'cislo': 22,
        #'cislo_orientacni': '',
        #'longitude': 13.8956472222,
        #'provozni_doba': 'L: 6:00 - 20:00, Z: 6:00 - 18:00',
        #'latitude': 49.5122666667,
        #'psc': '38743',

        #'cast_obce': 'Bělčice',
        #'id': 2,
        #'okres': 'Strakonice',
        #'katastralni_uzemi': 'Bělčice ',
        #'active': 1,
        #'ulice': 'areál skladu Čepro a.s.',
        #'kraj': 'Kraj Jihočeský',
        #'telefon_stanice': '735720022',



    feature = Feature(geometry=Point((s['longitude'], s['latitude'])), properties=props)

    tile = latlonToTilenumber(dataset['zoom'], s['latitude'], s['longitude'])
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



# some final stats
print("\n-----------------------------------------------------")
#print("Total lines: %d, missing coors: %d, errors: %s" % (line_counter, missing_count, error_count))
print('Fuel stations: %d' % (len(stations)))
print("-----------------------------------------------------")

