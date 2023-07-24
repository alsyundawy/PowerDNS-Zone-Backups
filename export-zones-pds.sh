#!/bin/bash

# creates dump/export/backup of all DNS zones

if [ ! -d /var/lib/powerdns/zones ]; then
  if [ ! -d /var/lib/powerdns ]; then
    mkdir /var/lib/powerdns
  fi
  mkdir /var/lib/powerdns/zones
fi

zones=(`/usr/bin/pdnsutil list-all-zones`)
today=`date +%Y%m%d`

for z in "${!zones[@]}"
do

  /usr/bin/pdnsutil list-zone ${zones[$z]} > "/var/lib/powerdns/zones/${zones[$z]}-$today.zone"

done

find /var/lib/powerdns/zones/ -type f -name '*.zone' -mtime +28 -exec rm {} \;
