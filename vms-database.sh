#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

if [[ "${1:-}" == "-h" ]]; then
	echo "vms-database.sh <DMP> <deployment>"
	exit 0
fi

DMP="clouddemo-vcloud-${1:-prod}"
DEPLOYMENT="${2:-tom-not-tom-2}"

depInternalName=$( kubectl --context=lf99 --namespace "$DMP" get ingress | grep "$DEPLOYMENT" | cut -d " " -f 1 )
DEPLOYMENT=$( kubectl get pods --namespace="$DMP" | grep "$depInternalName.*Running" | sed 's/\([^ ]*\) .*/\1/' )

if [[ ! -z "$DEPLOYMENT" ]]; then
	echo "DMP: $DMP"
	echo "DEPLOYMENT: $DEPLOYMENT"
	echo kubectl -n "$DMP" exec -ti "$DEPLOYMENT" --container db -- psql -U postgres -d vaionmgmt
	echo
	echo
	kubectl -n "$DMP" exec -ti "$DEPLOYMENT" --container db -- psql -U postgres -d vaionmgmt
else
	echo "Wrong arguments"
	echo $DMP
	echo $DEPLOYMENT
fi