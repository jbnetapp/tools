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

check_var

set -x
#yum update -y
yum install tuned -y
yum install grubby -y
yum install sshpass -y
yum install device-mapper -y
yum install device-mapper-multipath -y

# packages require for Mediator
yum install openssl -y
yum install openssl-devel -y 
yum install gcc -y 
yum install make -y 
yum install redhat-lsb-core -y 
yum install patch -y 
yum install bzip2 -y 
yum install python36 -y 
yum install python36-devel -y 
yum install python36-pip -y
yum install libselinux-utils -y 
yum install perl-Data-Dumper -y 
yum install perl-ExtUtils-MakeMaker -y 
yum install policycoreutils-python -y


# change session timeo
clean_and_exit "terminate" 0
