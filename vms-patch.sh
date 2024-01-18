#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

COMPONENT="${1:-mgmt}"

if [[ "$COMPONENT" == "-h" ]]; then
	echo "vms-patch.sh <component> <deployment> <DMP> <context>"
	exit 0
fi

DEPLOYMENT="${2:-tom-not-tom-2}"
DMP="${3:-prod}"
context="${4:-aw1}"

if [ "$#" -ge 4 ]; then
	shift 4
else
	shift "$#"
fi

echo "~/go/src/repo.jazznetworks.com/vaion/vaion/go/cloud/scripts/patch-vms $DEPLOYMENT $COMPONENT $DMP" --context=$context "$@"

~/go/src/repo.jazznetworks.com/vaion/vaion/go/cloud/scripts/patch-vms "$DEPLOYMENT" "$COMPONENT" "$DMP" --context=$context "$@"