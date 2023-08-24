#!/bin/bash
basename=`basename $0`
dirname=`dirname $0`
source ${dirname}/token.conf
cat ${dirname}/response.json | python -mjson.tool
