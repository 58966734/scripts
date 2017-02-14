#!/bin/bash

read -p "�붨�����ݿ�ʵ������: " m1
if [ -z $m1 ];then
    echo "error,the name of database instance must not null"
    exit
fi
#�������ݿ�ʵ����
#m1=broadcast-classroom

#ϵͳ����
systemctl stop firewalld
setenforce 0
yum install -y perl-Module-Install.noarch libaio libaio-devel autoconf

#��鼰�����ϰ汾�������ļ�
yum -y remove mysql-libs
rpm -qa |grep -i mysql|xargs -I {} rpm -e --nodeps {}
rpm -qa |grep mariadb|xargs -I {} rpm -e --nodeps {}
rm -rf /var/lib/mysql*
rm -rf /usr/share/mysql*

#����mysql�鼰�û�
groupadd mysql
useradd mysql -g mysql
id mysql

#���
mkdir /data/soft -p
wget http://172.16.1.99/MySQL/MySQL-5.6.31/Linux/MySQL-5.6.31-1.el6.x86_64.rpm-bundle.tar -P /data/soft

if [ -f /data/soft/MySQL-5.6.31-1.el6.x86_64.rpm-bundle.tar ];then
    tar xf /data/soft/MySQL-5.6.31-1.el6.x86_64.rpm-bundle.tar -C /tmp/
else
    echo "error,/data/soft/MySQL-5.6.31-1.el6.x86_64.rpm-bundle.tar not found"
    exit
fi

#RPM��װ
rpm -ivh /tmp/MySQL-shared-5.6.31-1.el6.x86_64.rpm
rpm -ivh /tmp/MySQL-devel-5.6.31-1.el6.x86_64.rpm
rpm -ivh /tmp/MySQL-client-5.6.31-1.el6.x86_64.rpm
rpm -ivh /tmp/MySQL-server-5.6.31-1.el6.x86_64.rpm


#DataĿ¼
mkdir -pv /data/mysqlData/$m1/data
mkdir -pv /data/mysqlData/$m1/tmp
#LogĿ¼
mkdir -pv /data/mysqlLog/$m1/logs
#�����ļ�Ŀ¼
mkdir -pv /data/mysqlConfig
#socketĿ¼
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

#MySQLѡ���Ա����ⲿ����
skip-external-locking

#��ֹMySQL���ⲿ���ӽ���DNS������ʹ����һѡ���������MySQL����DNS������ʱ�䡣
#����Ҫע�⣬���������ѡ�������Զ������������Ȩ��Ҫʹ��IP��ַ��ʽ������MySQL���޷�����������������
skip-name-resolve

#��������������ôӷ������ĸ����Ƿ�д���������־�����ѡ��Ĭ���ǲ��򿪵ġ�
#���ǣ��������ӷ�����B�Ƿ�����A�Ĵӷ�������ͬʱ����Ϊ������C��������������ô����Ҫ�����ѡ��������Ĵӷ�����C���ܻ�����Ķ�������־����ͬ������
log-slave-updates

#��ʾ����Ҫͬ�������ݿ�
binlog-ignore-db = mysql.%
binlog-ignore-db = information_schema.%

#��ʾ����Ҫ���Ƶ����ݿ�
replicate_ignore_db = mysql.%
replicate_ignore_db = information_schema.%

#��������ѯ
slow-query-log

#������ѯ����
explicit_defaults_for_timestamp=true

#binlog��־��ʽ
# Ĭ�������֣�����ѡ��mixed�����ʹ�ã�һ��ĸ���ʹ��STATEMENTģʽ����binlog������STATEMENTģʽ�޷����ƵĲ���ʹ��ROWģʽ����binlog��MySQL�����ִ�е�SQL���ѡ����־���淽ʽ��
binlog_format = mixed
max_binlog_size = 512M
binlog_cache_size = 1M  #Ĭ��binlog_cache_size��32K
expire-logs-days = 30   #����30���binlogɾ��

#MySQL���е�����������
back_log = 500

#MySQL�����������������������Ĳ��������������Ƚϴ󣬽�����ߴ�ֵ�������Ӳ�����������
max_connections = 2048

#����ѯʱ�䳬��1����Ϊ����ѯ
long_query_time = 1

#�����������û���Դ��
max_user_connections = 2000
#��һ��MySQL���밲ȫ�йصļ�����ֵ����������ֹ���ೢ��ʧ�ܵĿͻ����Է�ֹ�����ƽ���������
max_connect_errors = 10000

#�������رշǽ�������֮ǰ�ȴ����������
wait_timeout = 28800

#�������رս���ʽ����ǰ�ȴ����������
interactive_timeout = 28800
#���趨Զ���û������ӦPORT�����������ӵ����ʱ�䡣��λ���롣Ĭ��ֵ��60
connect_timeout = 20

#��slave��Ϊ����master������������ʱ���͵ȴ�N�룬Ȼ��Ͽ����ӣ���������master��
slave-net-timeout = 30

#relay log�ܶ෽�涼��binary log��࣬�����ǣ��ӷ�����I/O�߳̽����������Ķ�������־��ȡ������¼���ӷ����������ļ���Ȼ��SQL�̻߳��ȡrelay-log��־�����ݲ�Ӧ�õ��ӷ�������
relay-log = relay-bin

max-relay-log-size = 256M

#MySQL֧��4��������뼶�����Ƿֱ��ǣ�
#READ-UNCOMMITTED, READ-COMMITTED, REPEATABLE-READ, SERIALIZABLE.
#��û��ָ����MySQLĬ�ϲ��õ���REPEATABLE-READ��ORACLEĬ�ϵ���READ-COMMITTED
transaction_isolation = READ-COMMITTED  # ����ö��Ͳ����ظ������������������

#mysql5.5 �汾 ������һ�������Ż������棺 PERFORMANCE_SCHEMA�������Ĭ���ǹرյ�
performance_schema = 1

#������ͬһʱ����mysqld������session��prepared �������ޡ�
#����ȡֵ��ΧΪ��0 - 1048576����Ĭ��Ϊ16382��
max_prepared_stmt_count=65535
#Buffer Cache

#ָ�������������Ĵ�С������������������ٶȣ����������������ٶȡ�
key_buffer_size = 64M
#����max_allowed_packet���ֵ����������������1G������ʵ����mysql�ͻ������ֻ֧��16M��
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
 
#��Ȩ:��������
chown -R mysql.mysql /data/mysqlData/$m1/data
chown -R mysql.mysql /data/mysqlData/$m1/tmp
chown -R mysql.mysql /data//mysqlLog/$m1/logs
chown -R mysql.mysql /data/mysqlConfig
chown -R mysql.mysql /data/mysqlSocket

#���ݿ��ʼ��
mysql_install_db --defaults-file=/data/mysqlConfig/my3306.cnf --user=mysql
#���ݿ�����
mysqld_safe --defaults-file=/data/mysqlConfig/my3306.cnf --user=mysql&
#���ݿ��޸�����
mysqlPassword="PASSWORD"
mysqladmin -uroot -S /data/mysqlSocket/my3306.sock -p password $mysqlPassword
#���ݿ��¼
mysql -uroot -p$mysqlPassword -S /data/mysqlSocket/my3306.sock
#���ݿ�ر�
#mysqladmin -uroot -p -S /data/socket/mysql3306.sock shutdown

#
#mysqladmin -uroot -S /data/mysqlSocket/my3306.sock -p password "PASSWORD"
#
#grant all on *.* to 'admin'@'%' identified by 'PASSWORD';
# 
#mysql -uroot -pPASSWORD -S /data/mysqlSocket/my3306.sock chineseBon_devp <trial_chineseBon_20161102_0130.sql
#
#mysql -uadmin -pPASSWORD -h 172.16.1.101
