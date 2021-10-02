#!/usr/bin/env python
"""Process Z-Boxes dataset from Zásilkovna for OSM import.

Reads input JSON file, convert it and generate tiles for POI-Importer

More info on
 Github: https://github.com/mkyral/osm/tree/master/import/zasilkovna
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
__copyright__ = "Copyright 2021"
__credits__ = ["Marián Kyral"]
__license__ = "GPLv3+"
__version__ = "1.0"
__maintainer__ = "Marián Kyral"
__email__ = "mkyral@email.cz"
__status__ = "Test"

# configuration
osm_precision = 7
bbox = {'min': {'lat': 48.55, 'lon': 12.09}, 'max': {'lat': 51.06, 'lon': 18.87}}

# where to store POI-Importer tiles
tiles_config="tiles/dataset.json"
tiles_dir="tiles/data"

# Get tile xy coors
def latlonToTilenumber(zoom, lat, lon):
    n = (2 ** zoom);
    lat_rad = lat * pi / 180;
    return ({
            "x": floor(n * ((lon + 180) / 360)),
            "y": floor(n * (1 - (log(tan(lat_rad) + 1/cos(lat_rad)) / pi)) / 2) })

# Read input parameters
program_name = sys.argv[0]
arguments = sys.argv[1:]

if (len(arguments) < 1):
    print("Usage: %s IN_JSON_FILE" % (program_name))
    exit(1)

infile = arguments[0]

# Load dataset config file
try:
    with open(tiles_config) as cfg:
        dataset = json.load(cfg)
        print("Zoom: %s" % (dataset['zoom']))
except Exception as error:
    print('Error during loading of dataset configuration file!')
    print(error)
    exit(1)

files = {}

print("\nLoading JSON file...")
start_time = time.time()
cnt = 0
try:
    with open(infile) as inputfile:
        injson = json.load(inputfile)

        data = injson['data']
        for key in data:
            record = data[key]

            if record['status']['statusId'] == '5' or record['country'] != 'cz' or record['displayFrontend'] == '0' or record['place'] != 'Z-BOX':
                continue

            cnt = cnt+1
            props = {}
            props['amenity'] = 'vending_machine'
            props['vending'] = 'parcel_pickup'
            props['source'] = 'zasilkovna'
            props['operator'] = 'Zásilkovna'

            props['ref'] = record['id']
            props['postal_code'] = record['zip']
            props['wheelchair'] = record['wheelchairAccessible']
            props['website'] = record['url']

            props['_note'] = ('<br><b>Popis:</b> %s <br><b>Stav:</b> %s ' % (record['name'], record['status']['description']))

            feature = Feature(geometry=Point((float(record['longitude']), float(record['latitude']))), properties=props)

            tile = latlonToTilenumber(dataset['zoom'], float(record['latitude']), float(record['longitude']))
            filename = "%s/%s_%s.json" % (tiles_dir, tile['x'], tile['y'])

            if filename not in files:
                coll = []
                files[filename] = coll

            files[filename].append(feature)
except Exception as error:
    print('Error :-(')
    print(error)
    exit(1)

print ("...JSON file processsed in %ss, Total of %i z-boxes exported" % (round(time.time() - start_time, 2), cnt))

# write tiles
start_time_tiles = time.time()
try:
    for k in sorted(files.keys()):
        feature_collection = FeatureCollection(files[k])

        with open(k, encoding='utf-8', mode='w+') as geojsonfile:
            geojsonfile.write(json.dumps(feature_collection, ensure_ascii=False, indent=2, sort_keys=True))

except Exception as error:
    print('Error :-(')
    print(error)
    exit(1)

print ("...Tiles generated in %ss" % (round(time.time() - start_time_tiles, 2)))


