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
import os
import datetime
import json
import subprocess

import pyproj

#https://github.com/frewsxcv/python-geojson
from geojson import Feature, Point, FeatureCollection

# for distance calculation
from math import sin, cos, tan, sqrt, atan2, radians, pi, floor, log

from urllib import request

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
#import_file_url = "https://www.zasilkovna.cz/api/v4/9b18b74fdb70e8f9/branch.json" # API v4
import_file_url = "https://pickup-point.api.packeta.com/v5/9b18b74fdb70e8f9/box.json" # API v5
server_data_dir = 'POI-Importer-testing/datasets/Czech-Zasilkovna-Z-BOXy/data/'

# where to store POI-Importer tiles
tiles_dir = "tiles"
tiles_config = tiles_dir + "/dataset.json"
tiles_data_dir = "tiles/data"
ts_file = "updated.json"

# Get tile xy coors
def latlonToTilenumber(zoom, lat, lon):
    n = (2 ** zoom);
    lat_rad = lat * pi / 180;
    return ({
            "x": floor(n * ((lon + 180) / 360)),
            "y": floor(n * (1 - (log(tan(lat_rad) + 1/cos(lat_rad)) / pi)) / 2) })

def processOpeningHours(oh):

    times = {}
    for day in oh:
        if type(oh['monday']) != str:
            continue
        #print(oh[day])
        time = oh[day].replace('–', '-')
        if not time in times:
            times[time] = [day[0:2].capitalize()]
        else:
            times[time].append(day[0:2].capitalize())

    if len(times) == 0:
        return ''

    if len(times.keys()) == 1:
        time = list(times.keys())[0]
        if time == '00:00-23:59' and len(times[time]) == 7:
            return ("24/7")
        if len(times[time]) == 7:
            return (time)

        ret = []
        for day in times[time]:
            ret.append(day)
        return ",".join(ret)+" "+times[time]
    else:
        ret = []
        for time in times.keys():
            ret.append(",".join(times[time])+" "+time)
        return "; ".join(ret)

    #print(3)
    return ''

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

infile = "zbox_%s.json" % (datetime.date.today().strftime("%Y%m%d"))

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

        for record in data:

            if record['status']['statusId'] == '5' or record['country'] not in ['cz','sk'] or record['type'] != 'zbox':
                continue

            cnt = cnt+1
            props = {}
            props['amenity'] = 'parcel_locker'
            props['brand'] = 'Packeta'
            props['brand:wikidata'] = 'Q67809905'
            props['source'] = 'zasilkovna'
            props['operator'] = 'Zásilkovna'
            props['operator:wikidata'] = 'Q25454926'

            props['ref'] = record['id']
            props['postal_code'] = record['zip']
            props['wheelchair'] = record['wheelchairAccessible']
            props['website'] = record['url']

            oh = processOpeningHours(record['openingHours']['regular'])
            if len(oh) > 0:
                props['opening_hours'] = oh

            props['parcel_pickup'] = 'yes'
            if record['packetConsignment'] == "1":
                props['parcel_mail_in'] = 'yes'
            else:
                props['parcel_mail_in'] = 'no'

            props['_note'] = ('<br><b>Popis:</b> %s <br><b>Stav:</b> %s ' % (record['name'], record['status']['description']))

            feature = Feature(geometry=Point((float(record['longitude']), float(record['latitude']))), properties=props)

            tile = latlonToTilenumber(dataset['zoom'], float(record['latitude']), float(record['longitude']))
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


#print ("cd %s" % tiles_data_dir)
#print ("rsync -r --del --compress ./ mkyral@openstreetmap.cz:/var/www/poi-importer/datasets/Czech-Zasilkovna-Z-BOXy/data")

#print ("cd .. #%s" % tiles_dir)
#print ("rsync -r --del --compress %s mkyral@openstreetmap.cz:/var/www/poi-importer/datasets/Czech-Zasilkovna-Z-BOXy/" % ts_file)

start_time_transfer = time.time()
os.chdir(tiles_data_dir)
subprocess.run(['rsync', '-r', '--del', '--compress', './', 'mkyral@openstreetmap.cz:/var/www/poi-importer/datasets/Czech-Zasilkovna-Z-BOXy/data'])

os.chdir(r"..")
subprocess.run(['rsync', '-r', '--del', '--compress', ts_file, 'mkyral@openstreetmap.cz:/var/www/poi-importer/datasets/Czech-Zasilkovna-Z-BOXy/'])

print ("...Files transfered in %ss" % (round(time.time() - start_time_transfer, 2)))
print ("Done!")

