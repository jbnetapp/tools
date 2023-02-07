#!/bin/bash
#set -x
basename=`basename $0`
dirname=`dirname $0`



gettext "Do you use Federated login ?[y/n]"
read ans 
if [ "$ans" == "y" ]; then
       	gettext "Enter your refresh token: "
       	read -s refresh_token
	JSON="{\"grant_type\": \"refresh_token\", \"refresh_token\": \"${refresh_token}\", \"client_id\": \"Mu0V1ywgYteI6w1MbD15fKfVIUrNXGWC\" }"
	echo $JSON
	curl -X POST https://netapp-cloud-account.auth0.com/oauth/token  -H 'Content-Type: application/json' -d "${JSON}" | python3 -mjson.tool
else
	gettext "username: "
	read username
	gettext "password: "
	read -s password
	echo
	JSON="{\"grant_type\": \"password\", \"username\": \"${username}\", \"password\": \"${password}\", \"audience\": \"https://api.cloud.netapp.com\" ,\"client_id\": \"QC3AgHk6qdbmC7Yyr82ApBwaaJLwRrNO\"}"
	echo $JSON
	curl -X POST https://netapp-cloud-account.auth0.com/oauth/token  -H 'Content-Type: application/json' -d "$JSON" | python3 -mjson.tool
fi
