#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if [[ "${1:-}" == "-h" ]]; then
	echo "vms-database.sh <deployment> <DMP> <context>"
	exit 0
fi

DEPLOYMENT="${1:-tom-not-tom-2}"
DMP="clouddemo-vcloud-${2:-prod}"
context="${3:-lf99}"

depInternalName=$( kubectl --context="$context" --namespace "$DMP" get ingress | grep "$DEPLOYMENT" | cut -d " " -f 1 )
DEPLOYMENT=$( kubectl get pods --namespace="$DMP" --context=$"$context" | grep "$depInternalName.*Running" | grep "\-db" | sed 's/\([^ ]*\) .*/\1/' )

if [[ ! -z "$DEPLOYMENT" ]]; then
	echo "DMP: $DMP"
	echo "DEPLOYMENT: $DEPLOYMENT"
	echo kubectl -n "$DMP" exec -ti "$DEPLOYMENT" --context=$context --container db -- psql -U postgres -d vaionmgmt
	echo
	echo
	kubectl -n "$DMP" exec -ti "$DEPLOYMENT" --context=$context --container db -- psql -U postgres -d vaionmgmt
else
	echo "Wrong arguments"
	echo $DEPLOYMENT
	echo $DMP
fi