#!/bin/bash

read -p "请定义数据库实例名称: " m1
if [ -z $m1 ];then
    echo "error,the name of database instance must not null"
    exit
fi
#定义数据库实例名
#m1=broadcast-classroom

#系统环境
systemctl stop firewalld
setenforce 0
yum install -y perl-Module-Install.noarch libaio libaio-devel autoconf

#检查及清理老版本及残余文件
yum -y remove mysql-libs
rpm -qa |grep -i mysql|xargs -I {} rpm -e --nodeps {}
rpm -qa |grep mariadb|xargs -I {} rpm -e --nodeps {}
rm -rf /var/lib/mysql*
rm -rf /usr/share/mysql*

#创建mysql组及用户
groupadd mysql
useradd mysql -g mysql
id mysql

#解包
mkdir /data/soft -p
wget http://172.16.1.99/MySQL/MySQL-5.6.31/Linux/MySQL-5.6.31-1.el6.x86_64.rpm-bundle.tar -P /data/soft

if [ -f /data/soft/MySQL-5.6.31-1.el6.x86_64.rpm-bundle.tar ];then
    tar xf /data/soft/MySQL-5.6.31-1.el6.x86_64.rpm-bundle.tar -C /tmp/
else
    echo "error,/data/soft/MySQL-5.6.31-1.el6.x86_64.rpm-bundle.tar not found"
    exit
fi

#RPM安装
rpm -ivh /tmp/MySQL-shared-5.6.31-1.el6.x86_64.rpm
rpm -ivh /tmp/MySQL-devel-5.6.31-1.el6.x86_64.rpm
rpm -ivh /tmp/MySQL-client-5.6.31-1.el6.x86_64.rpm
rpm -ivh /tmp/MySQL-server-5.6.31-1.el6.x86_64.rpm


#Data目录
mkdir -pv /data/mysqlData/$m1/data
mkdir -pv /data/mysqlData/$m1/tmp
#Log目录
mkdir -pv /data/mysqlLog/$m1/logs
#配置文件目录
mkdir -pv /data/mysqlConfig
#socket目录
mkdir -pv /data/mysqlSocket

cat >/data/mysqlConfig/my3306.cnf <<my3306_cnf
[client]
port = 3306
socket = /data/mysqlSocket/my3306.sock

[mysqld]
port = 3306
character-set-server = utf8

datadir = /data/mysqlData/$m1/data
tmpdir = /data/mysqlData/$m1/tmp
socket = /data/mysqlSocket/my3306.sock
pid-file = /data/mysqlSocket/my3306.pid
log-bin = /data/mysqlLog/$m1/logs/mysql-bin
log-error = /data/mysqlLog/$m1/$m1-err.log
slow-query-log-file = /data/mysqlLog/$m1/$m1-slow.log

#MySQL选项以避免外部锁定
skip-external-locking

#禁止MySQL对外部连接进行DNS解析，使用这一选项可以消除MySQL进行DNS解析的时间。
#但需要注意，如果开启该选项，则所有远程主机连接授权都要使用IP地址方式，否则MySQL将无法正常处理连接请求。
skip-name-resolve

#这个参数用来配置从服务器的更新是否写入二进制日志，这个选项默认是不打开的。
#但是，如果这个从服务器B是服务器A的从服务器，同时还作为服务器C的主服务器，那么就需要开这个选项，这样它的从服务器C才能获得它的二进制日志进行同步操作
log-slave-updates

#表示不需要同步的数据库
binlog-ignore-db = mysql.%
binlog-ignore-db = information_schema.%

#表示不需要复制的数据库
replicate_ignore_db = mysql.%
replicate_ignore_db = information_schema.%

#开启慢查询
slow-query-log

#开启查询缓存
explicit_defaults_for_timestamp=true

#binlog日志格式
# 默认有三种：这里选择mixed，混合使用，一般的复制使用STATEMENT模式保存binlog，对于STATEMENT模式无法复制的操作使用ROW模式保存binlog，MySQL会根据执行的SQL语句选择日志保存方式。
binlog_format = mixed
max_binlog_size = 512M
binlog_cache_size = 1M  #默认binlog_cache_size是32K
expire-logs-days = 30   #超过30天的binlog删除

#MySQL能有的连接数量。
back_log = 500

#MySQL的最大连接数，如果服务器的并发连接请求量比较大，建议调高此值，以增加并行连接数量
max_connections = 2048

#慢查询时间超过1秒则为慢查询
long_query_time = 1

#是用来限制用户资源的
max_user_connections = 2000
#是一个MySQL中与安全有关的计数器值，它负责阻止过多尝试失败的客户端以防止暴力破解密码的情况
max_connect_errors = 10000

#服务器关闭非交互连接之前等待活动的秒数。
wait_timeout = 28800

#服务器关闭交互式连接前等待活动的秒数。
interactive_timeout = 28800
#是设定远程用户必须回应PORT类型数据连接的最大时间。单位：秒。默认值：60
connect_timeout = 20

#当slave认为连接master的连接有问题时，就等待N秒，然后断开连接，重新连接master。
slave-net-timeout = 30

#relay log很多方面都跟binary log差不多，区别是：从服务器I/O线程将主服务器的二进制日志读取过来记录到从服务器本地文件，然后SQL线程会读取relay-log日志的内容并应用到从服务器。
relay-log = relay-bin

max-relay-log-size = 256M

#MySQL支持4种事务隔离级别，他们分别是：
#READ-UNCOMMITTED, READ-COMMITTED, REPEATABLE-READ, SERIALIZABLE.
#如没有指定，MySQL默认采用的是REPEATABLE-READ，ORACLE默认的是READ-COMMITTED
transaction_isolation = READ-COMMITTED  # 允许幻读和不可重复读，但不允许脏读；

#mysql5.5 版本 新增了一个性能优化的引擎： PERFORMANCE_SCHEMA这个功能默认是关闭的
performance_schema = 1

#限制了同一时间在mysqld上所有session中prepared 语句的上限。
#它的取值范围为“0 - 1048576”，默认为16382。
max_prepared_stmt_count=65535
#Buffer Cache

#指定索引缓冲区的大小，它决定索引处理的速度，尤其是索引读的速度。
key_buffer_size = 64M
#首先max_allowed_packet这个值理论上最大可以设置1G，但是实际上mysql客户端最大只支持16M。
max_allowed_packet = 16M

table_open_cache = 6144
table_definition_cache = 4096
sort_buffer_size = 512K
read_buffer_size = 512K
read_rnd_buffer_size = 512k
join_buffer_size = 512K
myisam_sort_buffer_size = 32M
tmp_table_size = 32M
max_heap_table_size = 64M
query_cache_type=0
query_cache_size = 0
bulk_insert_buffer_size = 32M
thread_cache_size = 64
thread_stack = 192K
skip-slave-start


# InnoDB
innodb_data_home_dir = /data/mysqlData/$m1/data
innodb_log_group_home_dir = /data/mysqlLog/$m1/logs
innodb_data_file_path = ibdata1:1G:autoextend
innodb_buffer_pool_size = 2G

innodb_buffer_pool_instances=8
innodb_log_file_size = 512M
innodb_log_buffer_size = 64M

innodb_log_files_in_group = 3
innodb_flush_log_at_trx_commit = 0
innodb_lock_wait_timeout=100
innodb_sync_spin_loops = 40
innodb_max_dirty_pages_pct = 90
innodb_support_xa = 0
innodb_thread_concurrency = 0
innodb_thread_sleep_delay = 500
innodb_file_io_threads    = 4
innodb_concurrency_tickets = 1000
log_bin_trust_function_creators = 1
innodb_flush_method = O_DIRECT
innodb_file_per_table
innodb_read_io_threads = 2
innodb_write_io_threads = 2
innodb_io_capacity = 2000
innodb_file_format = Barracuda
innodb_file_format_max = Barracuda
innodb_purge_threads=1
innodb_purge_batch_size = 32
innodb_old_blocks_pct=75
innodb_change_buffering=all

[mysqldump]
quick
max_allowed_packet = 128M
myisam_max_sort_file_size = 10G

[mysql]
no-auto-rehash

[myisamchk]
key_buffer_size = 64M
sort_buffer_size = 512k
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout

[mysqld_safe]
open-files-limit = 28192

my3306_cnf
 
#赋权:属主属组
chown -R mysql.mysql /data/mysqlData/$m1/data
chown -R mysql.mysql /data/mysqlData/$m1/tmp
chown -R mysql.mysql /data//mysqlLog/$m1/logs
chown -R mysql.mysql /data/mysqlConfig
chown -R mysql.mysql /data/mysqlSocket

#数据库初始化
mysql_install_db --defaults-file=/data/mysqlConfig/my3306.cnf --user=mysql
#数据库启动
mysqld_safe --defaults-file=/data/mysqlConfig/my3306.cnf --user=mysql&
#数据库修改密码
mysqlPassword="PASSWORD"
mysqladmin -uroot -S /data/mysqlSocket/my3306.sock -p password $mysqlPassword
#数据库登录
mysql -uroot -p$mysqlPassword -S /data/mysqlSocket/my3306.sock
#数据库关闭
#mysqladmin -uroot -p -S /data/socket/mysql3306.sock shutdown

#
#mysqladmin -uroot -S /data/mysqlSocket/my3306.sock -p password "PASSWORD"
#
#grant all on *.* to 'admin'@'%' identified by 'PASSWORD';
# 
#mysql -uroot -pPASSWORD -S /data/mysqlSocket/my3306.sock chineseBon_devp <trial_chineseBon_20161102_0130.sql
#
#mysql -uadmin -pPASSWORD -h 172.16.1.101
