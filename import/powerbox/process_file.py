#!/usr/bin/env python
"""Process charging stations from POWERBOX for OSM import.

Reads input JSON file, convert it and generate tiles for POI-Importer

More info on
 Github: https://github.com/mkyral/osm/tree/master/import/powerbox
 @talk-cz: https://lists.openstreetmap.org/listinfo/talk-cz
"""

import csv
import sys
import time
import os
import datetime
import json
import subprocess

import pyproj

from geojson import Feature, Point, FeatureCollection

# for distance calculation
from math import sin, cos, tan, sqrt, atan2, radians, pi, floor, log

from urllib import request

__author__ = "Ondřej Nový"
__copyright__ = "Copyright 2025"
__credits__ = ["Marián Kyral", "Ondřej Nový"]
__license__ = "GPLv3+"
__version__ = "1.0"
__maintainer__ = "Ondřej Nový"
__email__ = "novy@ondrej.org"
__status__ = "Test"

# configuration
osm_precision = 7
bbox = {'min': {'lat': 48.55, 'lon': 12.09}, 'max': {'lat': 51.06, 'lon': 18.87}}
import_file_url = "https://www.powerbox.cloud/api/mapy-cz/feed"
server_data_dir = 'POI-Importer-testing/datasets/Czech-Powerbox/data/'

# where to store POI-Importer tiles
tiles_dir = "tiles"
tiles_config = tiles_dir + "/dataset.json"
tiles_data_dir = "tiles/data"
ts_file = "updated.json"

# sockets
sockets = {
    "domaci-zasuvka-230V": ["schuko", "2"],
    "univerzalni-nabijeni": ["xlr_3pin_cable", "1"],
    "nabijeni-system-bosch": ["bosch_3pin", "1"],
    "nabijeni-system-bosch-smart": ["bosch_5pin", "1"],
    "nabijeni-system-shimano": ["shimano_steps_5pin", "1"],
}

# Get tile xy coors
def latlonToTilenumber(zoom, lat, lon):
    n = (2 ** zoom);
    lat_rad = lat * pi / 180;
    return ({
            "x": floor(n * ((lon + 180) / 360)),
            "y": floor(n * (1 - (log(tan(lat_rad) + 1/cos(lat_rad)) / pi)) / 2) })


def reporthook(count, block_size, total_size):
    global start_time
    if count == 0:
        start_time = time.time()
        return
    duration = time.time() - start_time
    progress_size = int(count * block_size)
    speed = int(progress_size / (1024 * duration))
    if total_size != -1:
        percent = int(count*block_size*100/total_size)
        sys.stdout.write("\r...%d%%, %d MB, %d KB/s, %d seconds passed" %
                        (percent, progress_size / (1024 * 1024), speed, duration))
    else:
        sys.stdout.write("\r%d MB, %d KB/s, %d seconds passed" %
                        (progress_size / (1024 * 1024), speed, duration))
    sys.stdout.flush()

# Read input parameters
program_name = sys.argv[0]
arguments = sys.argv[1:]

## len(arguments) < 1

infile = "powerbox_%s.json" % (datetime.date.today().strftime("%Y%m%d"))

if (not os.path.exists(infile)):
    print("Downloading file: %s" % infile)
    request.urlretrieve(import_file_url, infile, reporthook)

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
        data = json.load(inputfile)

        for record in data['premises']:
            if 'address' not in record or \
                    'gps' not in record['address'] or \
                    'latitude' not in record['address']['gps'] or \
                    'longitude' not in record['address']['gps']:
                continue

            cnt = cnt+1
            props = {}
            props['amenity'] = 'charging_station'
            props['brand'] = 'Powerbox.one'
            props['brand:wikidata'] = 'Q131535492'
            props['source'] = 'powerbox'
            props['motorcar'] = 'no'
            props['bicycle'] = 'yes'
            props['fee'] = 'no'
            props['_note'] = 'Pokuste se na fotce stanice na adrese v tagu website spočítat počty konkrétních konektorů. Pokud je description delší než 255 znaků, je nutné ji smysluplně zkrátit.'
            props['ref'] = record['id']
            props['name'] = record['name'].removeprefix('Nabíjecí stanice ')
            if 'description' in record:
                props['description'] = record['description']
            if 'emails' in record:
                props['email'] = record['emails'][0]['email']
            if 'phones' in record:
                props['phone'] = '+420' + record['phones'][0]['number']
            props['website'] = record['additionalData']['url']
            for filter in record['filters']:
                if sockets[filter]:
                    props["socket:" + sockets[filter][0]] = sockets[filter][1]

            feature = Feature(geometry=Point((float(record['address']['gps']['longitude']), float(record['address']['gps']['latitude']))), properties=props)

            tile = latlonToTilenumber(dataset['zoom'], float(record['address']['gps']['latitude']), float(record['address']['gps']['longitude']))
            filename = "%s/%s_%s.json" % (tiles_data_dir, tile['x'], tile['y'])

            if filename not in files:
                coll = []
                files[filename] = coll

            files[filename].append(feature)
except Exception as error:
    print('Error :-(')
    print(error)
    exit(1)


print ("...JSON file processsed in %ss, Total of %i z-boxes exported" % (round(time.time() - start_time, 2), cnt))

# delete old tiles
for fileName in os.listdir(tiles_data_dir):
    #Check file extension
    if fileName.endswith('.json'):
        # Remove File
        os.remove(tiles_data_dir + '/' + fileName)

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

ts_obj = {"updated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M")}
with open(tiles_dir + '/' + ts_file, encoding='utf-8', mode='w+') as tsf:
    tsf.write(json.dumps(ts_obj, ensure_ascii=False))
    tsf.write('\n')


start_time_transfer = time.time()
#os.chdir(tiles_data_dir)
#subprocess.run(['rsync', '-r', '--del', '--compress', './', 'mkyral@openstreetmap.cz:/var/www/poi-importer/datasets/Czech-Powerbox/data'])

#os.chdir(r"..")
#subprocess.run(['rsync', '-r', '--del', '--compress', ts_file, 'mkyral@openstreetmap.cz:/var/www/poi-importer/datasets/Czech-Powerbox/'])

print ("...Files transfered in %ss" % (round(time.time() - start_time_transfer, 2)))
print ("Done!")
