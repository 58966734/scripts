#!/bin/bash

cd /usr/local/src
wget -c http://nchc.dl.sourceforge.net/project/denyhosts/denyhosts/2.6/DenyHosts-2.6.tar.gz
tar xf DenyHosts-2.6.tar.gz
cd DenyHosts-2.6
python setup.py install

cd /usr/share/denyhosts/
cat >denyhosts.cfg <<EOF
SECURE_LOG = /var/log/secure
HOSTS_DENY = /etc/hosts.deny
PURGE_DENY = 20m
BLOCK_SERVICE  = sshd
DENY_THRESHOLD_INVALID = 1
DENY_THRESHOLD_VALID = 10
DENY_THRESHOLD_ROOT = 5
DENY_THRESHOLD_RESTRICTED = 1
WORK_DIR = /usr/share/denyhosts/data
SUSPICIOUS_LOGIN_REPORT_ALLOWED_HOSTS=YES
HOSTNAME_LOOKUP=NO
LOCK_FILE = /var/lock/subsys/denyhosts
ADMIN_EMAIL = liuliguo@huayutime.com
SMTP_HOST = localhost
SMTP_PORT = 25
SMTP_FROM = DenyHosts <nobody@localhost>
SMTP_SUBJECT = DenyHosts Report
AGE_RESET_VALID=5d
AGE_RESET_ROOT=25d
AGE_RESET_RESTRICTED=25d
AGE_RESET_INVALID=10d
DAEMON_LOG = /var/log/denyhosts
DAEMON_SLEEP = 30s
DAEMON_PURGE = 1h
EOF

mkdir -p /etc/denyhosts/
cp denyhosts.cfg /etc/denyhosts/

cp daemon-control-dist daemon-control
chown root daemon-control
chmod 700 daemon-control

cp daemon-control /etc/init.d/denyhosts
chkconfig --add denyhosts
chkconfig denyhosts on
/etc/init.d/denyhosts start

echo "sshd: 211.103.178.162" >> /etc/hosts.allow

tail -n 2 /etc/hosts.deny
