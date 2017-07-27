#!/bin/bash

jmap=jmap
jstack=jstack

pid=$1

if [ -z $pid ];then
	echo need a \$1
	exit
fi

$jmap -heap $pid >jmapheap$pid.txt
$jmap -histo $pid >jmaphisto$pid.txt 
$jstack -F $pid >jstackF$pid.txt 
$jstack -l $pid >jstackl$pid.txt 
#$jmap -dump:format=b,file=$pid.dump $pid 
