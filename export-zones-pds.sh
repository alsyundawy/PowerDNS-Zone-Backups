#!/bin/bash

# creates dump/export/backup of all DNS zones

if [ ! -d /home/powerdns/zones ]; then
  if [ ! -d /home/powerdns ]; then
    mkdir /home/powerdns
  fi
  mkdir /home/powerdns/zones
fi

zones=(`/usr/bin/pdnsutil list-all-zones`)
today=`date +%Y%m%d`

for z in "${!zones[@]}"
do

  /usr/bin/pdnsutil list-zone ${zones[$z]} > "/home/powerdns/zones/${zones[$z]}-$today.zone"

done

find /home/powerdns/zones/ -type f -name '*.zone' -mtime +28 -exec rm {} \;
