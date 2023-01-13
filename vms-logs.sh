#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

if [[ "${1:-}" == "-h" ]]; then
	echo "vms-logs.sh <deployment> <DMP> <component> <don't follow?>"
	echo "use 'd' for defaults (tom-not-tom-2, prod, mgmt)"
	exit 0
fi

DEP="${1:-tom-not-tom-2}"
DMP="clouddemo-vcloud-${2:-prod}"
COMPONENT="${3:-mgmt}"

# Set defaults
if [[ "${1:-}" = "d" ]]; then
	DEP="tom-not-tom-2"
fi
if [[ "${2:-}" = "d" ]]; then
	DMP="clouddemo-vcloud-prod"
fi
if [[ "${3:-}" = "d" ]]; then
	COMPONENT=mgmt
fi


depInternalName=$( kubectl --context=lf99 --namespace "$DMP" get ingress | grep "$DEP" | cut -d " " -f 1 )
DEP_WITH_NUM=$( kubectl --context=gke_lively-falcon_europe-west1_lively-falcon-99 --namespace="$DMP" get pods | grep "$depInternalName" | cut -d " " -f 1 )

if [[ "${4:-}" != "" ]]; then
	echo "kubectl logs --context=gke_lively-falcon_europe-west1_lively-falcon-99 --namespace=$DMP $DEP_WITH_NUM --tail=500 $COMPONENT"
	kubectl logs --context=gke_lively-falcon_europe-west1_lively-falcon-99 --namespace="$DMP" "$DEP_WITH_NUM" --tail=500 "$COMPONENT"
else
	echo "kubectl logs --context=gke_lively-falcon_europe-west1_lively-falcon-99 --namespace=$DMP $DEP_WITH_NUM -f --tail=500 $COMPONENT"
	kubectl logs --context=gke_lively-falcon_europe-west1_lively-falcon-99 --namespace="$DMP" "$DEP_WITH_NUM" -f --tail=5000 "$COMPONENT"
fi