#!/bin/bash

BACKUP_DIR='/data/backup_mysql'
USER='root'
PASSWORD='PASSWORD'
SOCKET='/data/socket/my3344.scok'
BATE_DATANAME='chineseBon'
TRIAL_DATANAME='trial_chineseBon'
DATABASE='chineseBon trial_chineseBon'
CTIME=`date +%Y%m%d_%H%M`

BATE_DATADIR=$BACKUP_DIR/$BATE_DATANAME
TRIAL_DATADIR=$BACKUP_DIR/$TRIAL_DATANAME

if [ ! -d $BATE_DATADIR ];then
  mkdir $BATE_DATADIR
else
  /usr/bin/mysqldump -u${USER} -p${PASSWORD} -S${SOCKET} ${BATE_DATANAME} > $BATE_DATADIR/${BATE_DATANAME}'_'${CTIME}'.sql'
fi

if [ ! -d $TRIAL_DATADIR ];then
  mkdir $TRIAL_DATADIR
else
  /usr/bin/mysqldump -u${USER} -p${PASSWORD} -S${SOCKET} ${TRIAL_DATANAME} > $TRIAL_DATADIR/${TRIAL_DATANAME}'_'${CTIME}'.sql'
fi
