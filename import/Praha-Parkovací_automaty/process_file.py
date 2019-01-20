#!/usr/bin/env python
"""Process EuroOil data for OSM import.

Reads input json file from https://www.ceproas.cz/eurooil/cerpaci-stanice ,
convert it and generate tiles for POI-Importer

More info on
 Github: https://github.com/mkyral/osm/tree/master/import/EuroOil
 @talk-cz: https://lists.openstreetmap.org/listinfo/talk-cz
"""

import sys
import time
import re

#https://github.com/frewsxcv/python-geojson
import geojson
import json

from pyproj import Proj, transform

from math import sin, cos, tan, sqrt, atan2, radians, pi, floor, log


__author__ = "Marián Kyral"
__copyright__ = "Copyright 2019"
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

# -----------------
#     Functions
# -----------------

def convertCoors(iCRS, oCRS, ix, iy):
    inProj = Proj(init=iCRS)
    outProj = Proj(init=oCRS)
    ox,oy = transform(inProj,outProj,ix,iy)
    return ox,oy



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
    with open(infile) as geojsonfile:
        pois = json.load(geojsonfile)
        inCRS = pois['crs']['properties']['name']
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

pois_processed = 0;

for poi in pois['features']:
    if poi['type'] != 'Feature':
        continue

    if poi['geometry']['type'] != 'Point':
        continue

    pois_processed = pois_processed + 1
    x,y = poi['geometry']['coordinates']
    lon,lat = convertCoors(inCRS, 'epsg:4326', x, y)

    props = {}
    props['amenity'] = 'vending_machine'
    props['vending'] = 'parking_tickets'
    props['source'] = 'opendata.praha.eu'

    feature = geojson.Feature(geometry=geojson.Point((lon, lat)), properties=props)

    tile = latlonToTilenumber(dataset['zoom'], lat, lon)
    filename = "%s/%s_%s.json" % (tiles_dir, tile['x'], tile['y'])
    if filename not in files:
        coll = []
        files[filename] = coll
    files[filename].append(feature)

# write to file
try:
    for k in sorted(files.keys()):
        feature_collection = geojson.FeatureCollection(files[k])

        with open(k, encoding='utf-8', mode='w+') as geojsonfile:
            geojsonfile.write(json.dumps(feature_collection, ensure_ascii=False, indent=2, sort_keys=True))

except Exception as error:
    print('Error :-(')
    print(error)
    exit(1)

print ("...JSON file generated in %ss" % (round(time.time() - start_time, 2)))



# some final stats
print("\n-----------------------------------------------------")
print('POIs processed: %d' % (pois_processed))
print("-----------------------------------------------------")

