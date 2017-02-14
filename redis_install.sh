#!/bin/bash
wget http://download.redis.io/releases/redis-3.2.7.tar.gz -P /usr/local/src
tar xf /usr/local/src/redis-3.2.7.tar.gz

yum -y install gcc gcc-c++
yum -y install tcl

make && make install

redis-server -v

mkdir -p /usr/local/redis/etc
mkdir -p /usr/local/redis/var
mkdir -p /usr/local/redis/data

cp /usr/local/src/redis-3.2.7/redis.conf /usr/local/redis/etc/

sed -i '/^daemonize/cdaemonize yes' /usr/local/redis/etc/redis.conf
sed -i '/^pidfile/cpidfile /usr/local/redis/var/redis.pid' /usr/local/redis/etc/redis.conf
sed -i '/^logfile/clogfile /usr/local/redis/var/redis.log' /usr/local/redis/etc/redis.conf
sed -i '/^dir/cdir /usr/local/redis/data' /usr/local/redis/etc/redis.conf

redis-server /usr/local/redis/etc/redis.conf
