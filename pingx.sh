#!/bin/bash
netseg=172.16.1
for ((i=1;i<=254;i++))
do
    ping -c 1 $netseg.$i && echo "$netseg.$i" >>host-alive-`date +%F`.txt &
done