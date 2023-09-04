#!/bin/bash
################################
# Author: Hernan Urban
# Version: 1.0
################################

# Constants
IFS=$'\n'
YELLOW='\x1b[1m\x1B[33m'
RED='\x1b[1m\x1B[31m'
GREEN='\x1b[1m\x1B[32m'
BLUE='\x1b[1m\x1B[34m'
NC='\x1B[0m'
BOLD='\x1B[1m'
BLINK='\x1B[5m'
WARNING="[${YELLOW}WARN${NC}]"
INFO="[${BLUE}INFO${NC}]"
ERROR="[${RED}ERROR${NC}]"
INFOLN="[${BLUE}INFO${NC}] -----------------------------------------------------------------"
LINE='........................................................'

# Variables
PROJECT_ID=""
PREFIX=""
GH_OWNER=""
SERVICE_ACC=""
WL_ID_POOL=""
GH_PROVIDER_NAME=""
WORKLOAD_IDENTITY_POOL_ID==""
RESOURCE_NAME=""

if [[( "$#" -eq 1 ) && ( "$1" == "--help" ) || ( "$1" == "-h" )]]; then
    echo "This script will create a workload identity group, a WLID group provider"
    echo "and a service account to use as the Workload Identity Federation."
    echo "The poutcome will be a workload identity provider and"
    echo "the service account to use for example in the gihub actions pipelines."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "--project |  -p   GCP Project ID."
    echo "--prefix  |  -x   A custom prefix for unique identify."
    echo "--owner   |  -o   The github organization/team or username."
    echo "--help    |  -h   This help."
else
while [ $# -gt 0 ]
do
     case "$1" in
          --project) PROJECT_ID="$2"; shift;;
          -p) PROJECT_ID="$2"; shift;;
          --prefix) PREFIX="$2"; shift;;
          -x) PREFIX="$2"; shift;;
          --owner) GH_OWNER="$2"; shift;;
          -o) GH_OWNER="$2"; shift;;
          ---) shift;;
     esac
     shift;
done
if [ -z "$PROJECT_ID" ]
then 
	echo "Enter the Project ID"
	read PROJECT_ID
fi
if [ -z "$PREFIX" ]
then 
	echo "Enter a unique prefix for the resources"
	read PREFIX
fi
if [ -z "$GH_OWNER" ]
then 
	echo "Enter the github organization or username"
	read GH_OWNER
fi

# Set-up vars
SERVICE_ACC="${PREFIX}-service-account"
WL_ID_POOL="${PREFIX}-wl-id-pool"
GH_PROVIDER_NAME="${PREFIX}-gh-provider"

echo -e "${INFO} Creating service account"
gcloud iam service-accounts create "${SERVICE_ACC}" --project "${PROJECT_ID}"
echo -e "${INFO} Done."

echo -e "${INFO} Enabling google api services"
gcloud services enable iamcredentials.googleapis.com --project "${PROJECT_ID}"
echo -e "${INFO} Done."

echo -e "${INFO} Creating workload identity pools"
gcloud iam workload-identity-pools create "${WL_ID_POOL}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="${PREFIX} Workload Identity Pool"
echo -e "${INFO} Done."

echo -e "${INFO} Retrieving workload identity pool ID"
WORKLOAD_IDENTITY_POOL_ID=`gcloud iam workload-identity-pools describe "${WL_ID_POOL}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --format="value(name)"`
echo -e "${INFO} Done."

echo -e "${INFO} Creating workload identity pool provider"
gcloud iam workload-identity-pools providers create-oidc "${GH_PROVIDER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WL_ID_POOL}" \
  --display-name="${PREFIX} Github Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository_owner=assertion.repository_owner" \
  --issuer-uri="https://token.actions.githubusercontent.com"
echo -e "${INFO} Done."

echo -e "${INFO} Adding iam policy binding"
gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACC}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository_owner/${GH_OWNER}"
echo -e "${INFO} Done."

echo -e "${INFO} Retrieving workload identity provider name"
RESOURCE_NAME=`gcloud iam workload-identity-pools providers describe "${GH_PROVIDER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WL_ID_POOL}" \
  --format="value(name)"`
echo -e "${INFO} Done."

echo -e "${INFO} Adding iam policy binding with admin registry role"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" --member="serviceAccount:${SERVICE_ACC}@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/artifactregistry.admin"
echo -e "${INFO} Done."

echo "================================================================================"
echo "workload_identity_provider: ${RESOURCE_NAME}"
echo "service_account: ${SERVICE_ACC}@${PROJECT_ID}.iam.gserviceaccount.com"
fi