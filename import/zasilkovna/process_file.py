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

import pyproj

#https://github.com/frewsxcv/python-geojson
from geojson import Feature, Point, FeatureCollection

# for distance calculation
from math import sin, cos, tan, sqrt, atan2, radians, pi, floor, log

from urllib import request
from ftplib import FTP
import netrc

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
import_file_url = "https://www.zasilkovna.cz/api/v4/9b18b74fdb70e8f9/branch.json"
ftp_server = 'ftp2.gransy.com'
ftp_data_dir = 'POI-Importer-testing/datasets/Czech-Zasilkovna-Z-BOXy/data/'

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
        injson = json.load(inputfile)

        data = injson['data']
        for key in data:
            record = data[key]

            if record['status']['statusId'] == '5' or record['country'] != 'cz' or record['displayFrontend'] == '0' or record['place'] != 'Z-BOX':
                continue

            cnt = cnt+1
            props = {}
            props['amenity'] = 'parcel_locker'
            props['vending'] = 'parcel_pickup'
            props['source'] = 'zasilkovna'
            props['operator'] = 'Zásilkovna'

            props['ref'] = record['id']
            props['postal_code'] = record['zip']
            props['wheelchair'] = record['wheelchairAccessible']
            props['website'] = record['url']

            oh = processOpeningHours(record['openingHours']['regular'])
            if len(oh) > 0:
                props['opening_hours'] = oh

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

# Get list

local_files = []
for file in sorted(files.keys()):
    local_files.append(file.split('/')[-1])

# Sent to ftp server
auth = netrc.netrc();
ftp_user = auth.authenticators(ftp_server)[0]
ftp_pass = auth.authenticators(ftp_server)[2]
ftp_files = []

print('Start of FTP transfer')
with FTP(ftp_server) as ftp:
    ftp.login(ftp_user, ftp_pass)
    ftp.set_pasv(True)
    ftp.cwd(ftp_data_dir)
    print('Get list of existing tiles')
    for name, facts in ftp.mlsd():
        if name.endswith('json'):
            ftp_files.append(name);
    obsolete_files = (set(ftp_files).difference(local_files))
    print("Obsolete files: ", (obsolete_files))
    if len(obsolete_files) > 0:
        print('Delete obsolete files')
        for file in obsolete_files:
            ftp.delete(file)
    print('Copy files to server')
    for file in sorted(files.keys()):
        print ('Copying file: ', file)
        ftp.storbinary('STOR ' + file.split('/')[-1], open('./'+file, 'rb'))

# get list of obsolete (to be removed files)
obsolete_files = (set(ftp_files).difference(local_files))

