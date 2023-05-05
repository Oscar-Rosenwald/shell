#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

if [[ "${1:-}" == "-h" ]]; then
	echo "vms-logs.sh <deployment> <DMP> <component> <don't follow?> <context> <other options>"
	echo "use 'd' for defaults (tom-not-tom-2, prod, mgmt, f, lf99)"
	exit 0
fi

DEP="${1:-tom-not-tom-2}"
DMP="clouddemo-vcloud-${2:-prod}"
COMPONENT="${3:-mgmt}"
context="${5:-lf99}"
follow=true

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
if [[ "${4:-}" != "" ]]; then
	follow=false
fi
if [[ "${5:-}" = "d" ]]; then
	context=lf99
fi

if [[ "$#" -ge 5 ]]; then
	shift 5
else
	shift $#
fi

cat <<EOF
COMMAND:
VMS: $DEP
DMP: $DMP
Component: $COMPONENT
Context: $context
Don't Follow: ${4:-f}
EOF

depInternalName=$( kubectl --context=$context --namespace "$DMP" get ingress | grep "$DEP" | cut -d " " -f 1 )
DEP_WITH_NUM=$( kubectl --context=$context --namespace="$DMP" get pods | grep "$depInternalName" | grep -v "\-db-" | head -n 1 | cut -d " " -f 1 )

if [[ $follow = false ]]; then
	echo "kubectl logs --context=$context --namespace=$DMP $DEP_WITH_NUM --tail=500 $COMPONENT $@"
	kubectl logs --context=$context --namespace="$DMP" "$DEP_WITH_NUM" --tail=500 "$COMPONENT" "$@"
else
	echo "kubectl logs --context=$context --namespace=$DMP $DEP_WITH_NUM -f --tail=5000 $COMPONENT $@"
	kubectl logs --context=$context --namespace="$DMP" "$DEP_WITH_NUM" -f --tail=5000 "$COMPONENT" "$@"
fi