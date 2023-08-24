#!/bin/bash
set -x
basename=`basename $0`
dirname=`dirname $0`
source ${dirname}/token.conf

curl -k -X 'GET' \
  'https://snapctr.demo.netapp.com:8146/api/4.9/backups' \
  -H 'accept: application/json' \
  -H "Token: ${token}" > ${dirname}/response.json

${dirname}/read-response.sh
