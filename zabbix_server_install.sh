#/bin/bash

#install mysql-server-5.6.3
wget http://172.16.1.99/scripts/mysql_5_6_3_install.sh
bash mysql_5_6_3_install.sh
#
mysqlPasswd="PASSWORD"
DBHost=`hostname`
ListenIP="127.0.0.1"
#
yum install gcc gcc-c++ -y
yum install net-snmp-devel -y
yum install curl-devel -y
#
groupadd zabbix
useradd zabbix -g zabbix
#
ln -s /data/mysqlSocket/my3306.sock /tmp/mysql.sock
#
wget http://172.16.1.99/zabbix/zabbix-3.0.3.tar.gz -P /usr/local/src
tar xf /usr/local/src/zabbix-3.0.3.tar.gz -C /usr/local/src/
cd /usr/local/src/zabbix-3.0.3/
./configure --prefix=/usr/local/zabbix --enable-server --enable-proxy --enable-agent --with-mysql=/usr/bin/mysql_config --with-net-snmp --with-libcurl
make && make install

#mysqlPasswd=PASSWORD
mysql -uroot -S /data/mysqlSocket/my3306.sock -p$mysqlPasswd -e "create database zabbix character set utf8;"
mysql -uroot -S /data/mysqlSocket/my3306.sock -p$mysqlPasswd -e "grant all on zabbix.* to zabbix@localhost identified by 'zabbix';"
mysql -uroot -S /data/mysqlSocket/my3306.sock -p$mysqlPasswd -e "flush privileges;"
mysql -uroot -S /data/mysqlSocket/my3306.sock -p$mysqlPasswd -e "use zabbix;source /usr/local/src/zabbix-3.0.3/database/mysql/schema.sql;"
mysql -uroot -S /data/mysqlSocket/my3306.sock -p$mysqlPasswd -e "use zabbix;source /usr/local/src/zabbix-3.0.3/database/mysql/images.sql;"
mysql -uroot -S /data/mysqlSocket/my3306.sock -p$mysqlPasswd -e "use zabbix;source /usr/local/src/zabbix-3.0.3/database/mysql/data.sql;"
mysql -uroot -S /data/mysqlSocket/my3306.sock -p$mysqlPasswd -e "grant all on zabbix.* to 'zabbix'@'localhost' identified by 'zabbix';"
mysql -uroot -S /data/mysqlSocket/my3306.sock -p$mysqlPasswd -e "grant all on zabbix.* to 'zabbix'@'%' identified by 'zabbix';"

#
cp /usr/local/src/zabbix-3.0.3/misc/init.d/tru64/* /etc/init.d/
chmod 755 /etc/init.d/zabbix_*
sed -i '/^DAEMON=/cDAEMON=/usr/local/zabbix/sbin/zabbix_server' /etc/init.d/zabbix_server
sed -i '/^DAEMON=/cDAEMON=/usr/local/zabbix/sbin/zabbix_agentd' /etc/init.d/zabbix_agentd

#
#DBHost=`hostname`
#ListenIP="127.0.0.1"
mkdir /var/log/zabbix -p
cat >/usr/local/zabbix/etc/zabbix_server.conf << EOF
LogFile=/var/log/zabbix/zabbix_server.log
DBHost=$DBHost
DBName=zabbix
DBUser=zabbix
DBPassword=zabbix
ListenIP=$ListenIP
DBSocket=/data/mysqlSocket/my3306.sock
AlertScriptsPath=/usr/local/zabbix/share/zabbix/alertscripts
EOF
cat >/usr/local/zabbix/etc/zabbix_agentd.conf <<EOF
LogFile=/var/log/zabbix/zabbix_agentd.log
Server=127.0.0.1
EOF
touch /var/log/zabbix/zabbix_server.log
touch /var/log/zabbix/zabbix_agentd.log
chmod 777 /var/log/zabbix/zabbix_*

echo "172.16.1.180 $DBHost" >>/etc/hosts
/etc/init.d/zabbix_server start
/etc/init.d/zabbix_agentd start

#
wget http://172.16.1.99/Nginx/nginx-1.10.0.tar.gz -P /usr/local/src
wget http://172.16.1.99/Nginx/openssl-1.0.2h.tar.gz -P /usr/local/src
wget http://172.16.1.99/Nginx/pcre-8.38.tar.gz -P /usr/local/src
wget http://172.16.1.99/Nginx/zlib-1.2.8.tar.gz -P /usr/local/src

tar xf /usr/local/src/nginx-1.10.0.tar.gz -C /usr/local/src
tar xf /usr/local/src/openssl-1.0.2h.tar.gz -C /usr/local/src
tar xf /usr/local/src/pcre-8.38.tar.gz -C /usr/local/src
tar xf /usr/local/src/zlib-1.2.8.tar.gz -C /usr/local/src

groupadd nginx
useradd nginx -g nginx
cd /usr/local/src/nginx-1.10.0
./configure --user=nginx \
--group=nginx \
--prefix=/usr/local/nginx \
--with-openssl=../openssl-1.0.2h \
--with-http_ssl_module \
--with-pcre=../pcre-8.38 \
--with-http_stub_status_module 
make && make install

cat >/usr/local/nginx/conf/nginx.conf << EOF
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {
        listen       80;
        server_name  localhost;
        location / {
            root   html;
            index  index.php index.html index.htm;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
        location ~ \.php$ {
            root           html;
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  /scripts\$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}
EOF

cat >/usr/local/nginx/conf/fastcgi_params << eof
fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx;
fastcgi_param  QUERY_STRING       \$query_string;
fastcgi_param  REQUEST_METHOD     \$request_method;
fastcgi_param  CONTENT_TYPE       \$content_type;
fastcgi_param  CONTENT_LENGTH     \$content_length;
fastcgi_param  SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;
fastcgi_param  SCRIPT_NAME        \$fastcgi_script_name;
fastcgi_param  REQUEST_URI        \$request_uri;
fastcgi_param  DOCUMENT_URI       \$document_uri;
fastcgi_param  DOCUMENT_ROOT      "\$document_root";
fastcgi_param  SERVER_PROTOCOL    \$server_protocol;
fastcgi_param  REMOTE_ADDR        \$remote_addr;
fastcgi_param  REMOTE_PORT        \$remote_port;
fastcgi_param  SERVER_ADDR        \$server_addr;
fastcgi_param  SERVER_PORT        \$server_port;
fastcgi_param  SERVER_NAME        \$server_name;
eof

#############
wget http://172.16.1.99/php/libiconv-1.14.tar.gz -P /usr/local/src
tar zxf /usr/local/src/libiconv-1.14.tar.gz -C /usr/local/src
cd /usr/local/src/libiconv-1.14
./configure --prefix=/usr/local/libiconv
sed -i '1010d' srclib/stdio.h
make && make install

#
wget http://172.16.1.99/php/libmcrypt-2.5.7.tar.gz -P /usr/local/src
tar -zxf /usr/local/src/libmcrypt-2.5.7.tar.gz -C /usr/local/src
cd /usr/local/src/libmcrypt-2.5.7
./configure --prefix=/usr/local/libmcrypt
make && make install

#
yum -y install libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel libcurl libcurl-devel libxslt-devel
wget http://172.16.1.99/php/php-5.5.31.tar.gz -P /usr/local/src
tar -zxf /usr/local/src/php-5.5.31.tar.gz -C /usr/local/src
cd /usr/local/src/php-5.5.31
./configure \
--prefix=/usr/local/php \
--with-config-file-path=/usr/local/php/etc \
--with-mysql \
--with-mysqli=/usr/bin/mysql_config \
--with-pdo-mysql=mysqlnd \
--with-iconv-dir=/usr/local/libiconv \
--with-freetype-dir \
--with-jpeg-dir \
--with-png-dir \
--with-zlib \
--with-libxml-dir=/usr \
--with-gettext \
--enable-xml \
--disable-rpath \
--enable-bcmath \
--enable-shmop \
--enable-sysvsem \
--enable-inline-optimization \
--with-curl \
--enable-mbregex \
--enable-fpm \
--enable-mbstring \
--with-mcrypt=/usr/local/libmcrypt \
--with-gd \
--enable-gd-native-ttf \
--with-openssl \
--with-mhash \
--enable-pcntl \
--enable-sockets \
--with-xmlrpc \
--enable-soap \
--enable-short-tags \
--enable-static \
--with-xsl \
--with-fpm-user=nginx \
--with-fpm-group=nginx \
--enable-ftp \
--enable-opcache=no
make && make install

cp /usr/local/src/php-5.5.31/php.ini-production /usr/local/php/etc/php.ini
sed -i '/^max_execution_time/cmax_execution_time = 300' /usr/local/php/etc/php.ini
sed -i '/^max_input_time/cmax_input_time = 300' /usr/local/php/etc/php.ini
sed -i '/^memory_limit/cmemory_limit = 128M' /usr/local/php/etc/php.ini
sed -i '/^post_max_size/cpost_max_size = 32M' /usr/local/php/etc/php.ini
sed -i '/^;date.timezone/cdate.timezone = Asia/Shanghai' /usr/local/php/etc/php.ini
sed -i '/^;mbstring.func_overload/cmbstring.func_overload = 0' /usr/local/php/etc/php.ini

cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf
ln -s /usr/local/php/etc/php.ini /usr/local/php/lib/php.ini

cp ./sapi/fpm/php-fpm /etc/init.d/php-fpm
chmod +x /etc/init.d/php-fpm
/etc/init.d/php-fpm


cp -r /usr/local/src/zabbix-3.0.3/frontends/php /usr/local/nginx/html/zabbix
chown -R zabbix.zabbix /usr/local/nginx/html/zabbix
chmod -R 777 /usr/local/nginx/html/zabbix
/usr/local/nginx/sbin/nginx

yum install psmisc -y
#killall mysqld
#mysqld_safe --defaults-file=/data/mysqlConfig/my3306.cnf --user=mysql&
#/etc/init.d/zabbix_server start
#/etc/init.d/zabbix_agentd start
#/etc/init.d/php-fpm
#/usr/local/nginx/sbin/nginx
