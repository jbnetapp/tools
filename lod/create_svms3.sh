#!/bin/bash
#
set -x
VERSION=1.0
DIRNAME=`dirname $0`
CONFIG_FILE=${DIRNAME}/Setup.conf
FUNCTIONS_FILE=${DIRNAME}/functions.sh

if [ ! -f $CONFIG_FILE ] ; then
	echo "ERROR: Unable to read $CONFIG_FILE"
	exit 1
fi

. $CONFIG_FILE
. $FUNCTIONS_FILE

# Main
check_var 

echo Init SSH session host 
check_ssh_keyhost cluster1
check_ssh_keyhost cluster2

sshpass -p $PASSWD ssh -l admin cluster1 version 
sshpass -p $PASSWD ssh -l admin cluster2 version 

AGGR_DATA_CL1=`sshpass -p $PASSWD ssh -l admin cluster1 aggr show -root false |grep online |sort -k2 -u | tail -1 |awk '{print $1}'|tr -d '\r'`
[ -z "$AGGR_DATA_CL1" ] && clean_and_exit "ERROR: No Data Aggregate found in cluster1"

AGGR_DATA_CL2=`sshpass -p $PASSWD ssh -l admin cluster2 aggr show -root false |grep online |sort -k2 -u | tail -1 |awk '{print $1}'|tr -d '\r'`
[ -z "$AGGR_DATA_CL2" ] && clean_and_exit "ERROR: No Data Aggregate found in cluster2"


sshpass -p $PASSWD ssh -l admin cluster2 vserver create -vserver $SVM_S3
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_S3 -lif ${SVM_S3}_admin -service-policy default-management -address $SVM_S3_IP0 -netmask-length $LMASK -home-node cluster2-01 -home-port e0c

sshpass -p $PASSWD ssh -l admin cluster2 "set diag; network interface service-policy add-service -vserver $SVM_S3 -policy default-data-files -service data-s3-server -allowed-addresses 0.0.0.0/0"
sshpass -p $PASSWD ssh -l admin cluster2 network interface create -vserver $SVM_S3 -lif ${SVM_S3}_data1 -service-policy default-data-files -address $SVM_S3_IP1 -netmask-length $LMASK -home-node cluster2-01 -home-port e0c
sshpass -p $PASSWD ssh -l admin cluster2 certificate create -vserver $SVM_S3 -common-name $SVM_S3 -type server -size 2048 -country US -email-addr "admin@netapp.com" -cert-name ${SVM_S3}_cert
sshpass -p $PASSWD ssh -l admin cluster2 vserver object-store-server create -vserver $SVM_S3 -object-store-server $SVM_S3 -is-http-enabled true -certificate-name  ${SVM_S3}_cert
sshpass -p $PASSWD ssh -l admin cluster2 vserver cifs create -vserver $SVM_S3 -cifs-server $SVM_S3 -domain $DOMAIN -ou CN=Computers  
sshpass -p $PASSWD ssh -l admin cluster2 vserver services dns create -vserver $SVM_S3 -domains $DOMAIN -name-servers $NAME_SERVER 
sshpass -p $PASSWD ssh -l admin cluster2 vserver object-store-server user create -vserver $SVM_S3 -user $S3_USER 
sshpass -p $PASSWD ssh -l admin cluster2 volume create -vserver $SVM_S3 -volume volcifs1 -junction-path /volcifs1 -state online -security-style ntfs -aggregate $AGGR_DATA_CL2 
sshpass -p $PASSWD ssh -l admin cluster2 vserver cifs share create -vserver $SVM_S3 -share-name volcifs1 -path /volcifs1 
sshpass -p $PASSWD ssh -l admin cluster2 vserver object-store-server bucket create -bucket volcifs1 -type nas -vserver $SVM_S3 -nas-path /volcifs1
