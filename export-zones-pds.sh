#!/bin/bash

# creates dump/export/backup of all DNS zones

# Check if /home/powerdns/zones directory exists, if not, create it
if [ ! -d /home/powerdns/zones ]; then
  mkdir -p /home/powerdns/zones
fi

# Get list of all zones
zones=( $(/usr/bin/pdnsutil list-all-zones) )

# Get today's date in YYYYMMDD format
today=$(date +%Y%m%d)

# Loop through each zone and export it
for z in "${zones[@]}"
do
  /usr/bin/pdnsutil list-zone "$z" > "/home/powerdns/zones/${z}-${today}.zone"
done

# Remove zone files older than 28 days
find /home/powerdns/zones/ -type f -name '*.zone' -mtime +28 -exec rm {} \;
