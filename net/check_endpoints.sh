#!/bin/bash
#set -x
__RAINBOWPALETTE="1"
COLOR_ESCAPE="\e"
if [[ "$IS_MAC" == true ]]; then
  COLOR_ESCAPE="\033"
fi

function __colortext() {
  echo -e " $COLOR_ESCAPE[$__RAINBOWPALETTE;$2m$1$COLOR_ESCAPE[0m"
}

function echored() {
  echo $(__colortext "ERROR: $1" "31")
}

function echogreen() {
  echo $(__colortext "$1" "32")
}

function echoyellow() {
  echo $(__colortext "$1" "33")
}

# If no command line arg is passed. Set provider to missing.
if [ -z $1 ]
then
        provider="*** Cloud Provider Missing ***"
        echo ""
        echo "${provider}"
        echo "Valid Cloud Providers are: azure, aws, or gcp"
        echo "(NOTE:aws defaults to the us-east-1 region. This can be overwritten by providing a valid region code.)"
        echo ""
        echo "EXAMPLE: $0 aws ca-west-1"
        exit 1
elif [ -n $1 ]
# set provider the first arg passed
then
        provider=$1
fi

# check if there is a second arg passed used for the aws region
if [ -z $2 ]
# If there is no second arg passed, connectivity for the us-east-1 endpoints will be checked.
  then
    region="us-east-1"
elif [ -n $2 ]
# set provider the second arg if passed
then
        region="$2"
fi

# Declare an array with a list of URLs.
# IMPORTANT: Each URL (item) needs a corresponding PURPOSE (item)
# in the purpose array below.
#(i.e the first line's azure_url goes with the first line's azure_purpose)
declare -a azure_url=(
"https://management.azure.com"
"https://login.microsoftonline.com"
"https://management.usgovcloudapi.net"
"https://login.microsoftonline.com"
"https://api.services.cloud.netapp.com:443"
"https://cloud.support.netapp.com.s3.us-west-1.amazonaws.com"
"https://repo.cloud.support.netapp.com"
"https://cognito-idp.us-east-1.amazonaws.com"
"https://cognito-identity.us-east-1.amazonaws.com"
"https://sts.amazonaws.com"
"https://cloud-support-netapp-com-accelerated.s3.amazonaws.com"
"https://cloudmanagerinfraprod.azurecr.io"
"https://kinesis.us-east-1.amazonaws.com"
"https://cloudmanager.cloud.netapp.com"
"https://netapp-cloud-account.auth0.com"
"https://mysupport.netapp.com"
"https://support.netapp.com/svcgw"
"https://support.netapp.com/ServiceGW/entitlement"
"https://eval.lic.netapp.com.s3.us-west-1.amazonaws.com"
"https://cloud-support-netapp-com.s3.us-west-1.amazonaws.com"
"https://ipa-signer.cloudmanager.netapp.com"
"https://repo1.maven.org/maven2"
"https://oss.sonatype.org/content/repositories"
"https://repo.typesafe.com"
)

# Declare an array with a PURPOSE list to go with URL list in the above array.
# IMPORTANT: Each azure_purpose (item) needs a corresponding azure_purpose (item)
# in the url array above.
# (i.e the first line's azure_purpose goes with the first line's azure_url)
declare -a azure_purpose=(
"Enables Cloud Manager to deploy and manage Cloud Volumes ONTAP in Azure Public regions."
"Enables Cloud Manager to deploy and manage Cloud Volumes ONTAP in Azure Public regions."
"Enables Cloud Manager to deploy and manage Cloud Volumes ONTAP in the Azure US Gov regions."
"Enables Cloud Manager to deploy and manage Cloud Volumes ONTAP in the Azure US Gov regions."
"API requests to NetApp Cloud Central."
"Provides access to software images, manifests, and templates."
"Used to download Cloud Manager dependencies."
"Enables Cloud Manager to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Enables Cloud Manager to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Enables Cloud Manager to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Enables Cloud Manager to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Access to software images of container components for an infrastructure that’s running Docker and provides a solution for service integrations with Cloud Manager."
"Enables NetApp to stream data from audit records (required for Timeline)."
"Communication with the Cloud Manager service, which includes Cloud Central accounts."
"Communication with NetApp Cloud Central for centralized user authentication."
"Communication with NetApp AutoSupport."
"Communication with NetApp for system licensing and support registration."
"Communication with NetApp for system licensing and support registration."
"Communication with NetApp for system licensing and support registration."
"Communication with NetApp for system licensing and support registration."
"Enables Cloud Manager to generate licenses (for example, a FlexCache license for Cloud Volumes ONTAP)"
"During upgrades, Cloud Manager downloads the latest packages for third-party dependencies."
"During upgrades, Cloud Manager downloads the latest packages for third-party dependencies."
"During upgrades, Cloud Manager downloads the latest packages for third-party dependencies."
)

# Declare an array with a list of URLs.
# IMPORTANT: Each URL (item) needs a corresponding PURPOSE (item)
# in the purpose array below.
#(i.e the first line's aws_url goes with the first line's aws_purpose)
declare -a aws_url=(
"https://cloudformation.${region}.amazonaws.com"
"https://ec2.${region}.amazonaws.com"
"https://kms.${region}.amazonaws.com"
"https://sts.${region}.amazonaws.com"
"https://s3.${region}.amazonaws.com"
"https://api.services.cloud.netapp.com:443"
"https://cloud.support.netapp.com.s3.us-west-1.amazonaws.com"
"https://cognito-idp.us-east-1.amazonaws.com"
"https://cognito-identity.us-east-1.amazonaws.com"
"https://sts.amazonaws.com"
"https://cloud-support-netapp-com-accelerated.s3.amazonaws.com"
"https://cloudmanagerinfraprod.azurecr.io"
"https://kinesis.us-east-1.amazonaws.com"
"https://cloudmanager.cloud.netapp.com"
"https://netapp-cloud-account.auth0.com"
"https://support.netapp.com:443"
"https://support.netapp.com/svcgw"
"https://support.netapp.com/ServiceGW/entitlement"
"https://eval.lic.netapp.com.s3.us-west-1.amazonaws.com"
"https://cloud-support-netapp-com.s3.us-west-1.amazonaws.com"
"https://client.infra.support.netapp.com.s3.us-west-1.amazonaws.com"
"https://cloud-support-netapp-com-accelerated.s3.us-west-1.amazonaws.com"
"https://trigger.asup.netapp.com.s3.us-west-1.amazonaws.com"
"https://ipa-signer.cloudmanager.netapp.com"
"https://repo1.maven.org/maven2"
"https://oss.sonatype.org/content/repositories"
"https://repo.typesafe.com"
)

# Declare an array with a PURPOSE list to go with URL list in the above array.
# IMPORTANT: Each azure_purpose (item) needs a corresponding azure_purpose (item)
# in the url array above.
# (i.e the first line's aws_purpose goes with the first line's aws_url)
declare -a aws_purpose=(
"Enables the Connector to deploy and manage Cloud Volumes ONTAP in AWS."
"Enables the Connector to deploy and manage Cloud Volumes ONTAP in AWS."
"Enables the Connector to deploy and manage Cloud Volumes ONTAP in AWS."
"Enables the Connector to deploy and manage Cloud Volumes ONTAP in AWS."
"Enables the Connector to deploy and manage Cloud Volumes ONTAP in AWS."
"API requests to NetApp Cloud Central."
"Provides access to software images, manifests, and templates."
"Enables the Connector to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Enables the Connector to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Enables the Connector to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Enables the Connector to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Access to software images of container components for an infrastructure that’s running Docker and provides a solution for service integrations with Cloud Manager."
"Enables NetApp to stream data from audit records (Timeline needs this to work locally)"
"Communication with the Cloud Manager service, which includes Cloud Central accounts."
"Communication with NetApp Cloud Central for centralized user authentication."
"Communication with NetApp AutoSupport."
"Communication with NetApp for system licensing and support registration."
"Communication with NetApp for system licensing and support registration."
"Communication with NetApp for system licensing and support registration."
"Communication with NetApp for system licensing and support registration."
"Enables NetApp to collect information needed to troubleshoot support issues."
"Enables NetApp to collect information needed to troubleshoot support issues."
"Enables NetApp to collect information needed to troubleshoot support issues."
"Enables Cloud Manager to generate licenses (for example, a FlexCache license for Cloud Volumes ONTAP)"
"During upgrades, Cloud Manager downloads the latest packages for third-party dependencies."
"During upgrades, Cloud Manager downloads the latest packages for third-party dependencies."
"During upgrades, Cloud Manager downloads the latest packages for third-party dependencies."
)

# Declare an array with a list of URLs.
# IMPORTANT: Each URL (item) needs a corresponding PURPOSE (item)
# in the purpose array below.
#(i.e the first line's gcp_url goes with the first line's gpc_purpose)
declare -a gcp_url=(
"https://www.googleapis.com"
"https://api.services.cloud.netapp.com:443"
"https://cloud.support.netapp.com.s3.us-west-1.amazonaws.com"
"https://cognito-idp.us-east-1.amazonaws.com"
"https://cognito-identity.us-east-1.amazonaws.com"
"https://sts.amazonaws.com"
"https://cloud-support-netapp-com-accelerated.s3.amazonaws.com"
"https://cloudmanagerinfraprod.azurecr.io"
"https://kinesis.us-east-1.amazonaws.com"
"https://cloudmanager.cloud.netapp.com"
"https://netapp-cloud-account.auth0.com"
"https://support.netapp.com:443"
"https://support.netapp.com/svcgw"
"https://support.netapp.com/ServiceGW/entitlement"
"https://eval.lic.netapp.com.s3.us-west-1.amazonaws.com"
"https://cloud-support-netapp-com.s3.us-west-1.amazonaws.com"
"https://client.infra.support.netapp.com.s3.us-west-1.amazonaws.com"
"https://cloud-support-netapp-com-accelerated.s3.us-west-1.amazonaws.com"
"https://trigger.asup.netapp.com.s3.us-west-1.amazonaws.com"
"https://ipa-signer.cloudmanager.netapp.com"
"https://repo1.maven.org/maven2"
"https://oss.sonatype.org/content/repositories"
"https://repo.typesafe.com"
)

# Declare an array with a PURPOSE list to go with URL list in the above array.
# IMPORTANT: Each azure_purpose (item) needs a corresponding azure_purpose (item)
# in the url array above.
# (i.e the first line's gcp_purpose goes with the first line's gcp_url)
declare -a gcp_purpose=(
"Enables the Connector to contact Google APIs for deploying and managing Cloud Volumes ONTAP in GCP."
"API requests to NetApp Cloud Central."
"Provides access to software images, manifests, and templates."
"Enables the Connector to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Enables the Connector to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Enables the Connector to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Enables the Connector to access and download manifests, templates, and Cloud Volumes ONTAP upgrade images."
"Access to software images of container components for an infrastructure that’s running Docker and provides a solution for service integrations with Cloud Manager."
"Enables NetApp to stream data from audit records (Timeline needs this to work locally)"
"Communication with the Cloud Manager service, which includes Cloud Central accounts."
"Communication with NetApp Cloud Central for centralized user authentication."
"Communication with NetApp AutoSupport."
"Communication with NetApp for system licensing and support registration."
"Communication with NetApp for system licensing and support registration."
"Communication with NetApp for system licensing and support registration."
"Communication with NetApp for system licensing and support registration."
"Enables NetApp to collect information needed to troubleshoot support issues."
"Enables NetApp to collect information needed to troubleshoot support issues."
"Enables NetApp to collect information needed to troubleshoot support issues."
"Enables Cloud Manager to generate licenses (for example, a FlexCache license for Cloud Volumes ONTAP)"
"https://repo1.maven.org/maven2"
"https://repo1.maven.org/maven2"
"https://repo1.maven.org/maven2"
)

# Declare some color variables
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' #no color

# Display what Cloud Provider the script is checking for endpoint connectivity.
echoyellow "Checking for required endpoint connectivity for ${provider}..."

# Create the Azure function to be called when Azure is selected as the provider
Azure () {
for ((i=0;i<${#azure_url[@]};i++))
do

if curl --output /dev/null --silent --insecure -I -r 0-0 ${azure_url[$i]}; then
        echo "Endpoint reachable: ${azure_url[$i]}"
        echogreen "PURPOSE: ${azure_purpose[$i]}"
else
        echored "Endpoint NOT reachable: ${azure_url[$i]}"
        echored "   PURPOSE: ${azure_purpose[$i]}"
fi

done

}

# Create the AWS function to be called when AWS is selected as the provider
AWS () {
for ((i=0;i<${#aws_url[@]};i++))
do

if curl --output /dev/null --silent --insecure -I -r 0-0 ${aws_url[$i]}; then
        echo "Endpoint reachable: ${aws_url[$i]}"
        echogreen "PURPOSE: ${aws_purpose[$i]}"
else
        echored "Endpoint NOT reachable: ${aws_url[$i]} "
        echored "   PURPOSE: ${aws_purpose[$i]} "
fi

done

}

# Create the GCP function to be called when GCP is selected as the provider
GCP () {
for ((i=0;i<${#gcp_url[@]};i++))
do

if curl --output /dev/null --silent --insecure -I -r 0-0 ${gcp_url[$i]}; then
        echo "Endpoint reachable: ${gcp_url[$i]}"
        echogreen "   PURPOSE: ${gcp_purpose[$i]} "
else
        echored "Endpoint NOT reachable: ${gcp_url[$i]} "
        echored "   PURPOSE: ${gcp_purpose[$i]} "
fi

done

}

# Let the case statement decide which function to call based on the supplied
# provider arg passed from the cmd line

case ${provider} in
        "azure") Azure;;
        "aws") AWS;;
        "gcp") GCP;;
        *) echo "Invalid Cloud Provider. Valid Cloud Providers are: azure, aws or gcp";;
esac

# Hopefully a clean exit
exit 0

# Change log
# Created by Wil Shields version 2021.01.06
# initial release checks for either Azure endpoints or AWS endpoints.
# For AWS, if there is not a second arg passed when calling the script,
# the default is us-east-1. This can be overwritten by passing a proper region code
# example ./check_endpoints aws ca-central-1 (will check Canadian endpoints)
