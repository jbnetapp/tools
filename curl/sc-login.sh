#!/bin/bash
#set -x
basename=`basename $0`
dirname=`dirname $0`
source ${dirname}/token.conf

curl -k -X 'POST' \
  'https://snapctr.demo.netapp.com:8146/api/4.9/auth/login?TokenNeverExpires=false' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "UserOperationContext": {
    "User": {
      "Name": "demo\\administrator",
      "Passphrase": "Netapp1!",
      "Rolename": "SnapCenterAdmin"
    }
  }
}' > ${dirname}/response.json

${dirname}/read-response.sh
