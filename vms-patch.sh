#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

COMPONENT="${1:-mgmt}"

if [[ "$COMPONENT" == "-h" ]]; then
	echo "vms-patch.sh <component> <deployment> <DMP>"
	exit 0
fi

DEPLOYMENT="${2:-tom-not-tom-2}"
DMP="${3:-prod}"

if [ "$#" -ge 3 ]; then
	shift 3
else
	shift "$#"
fi

echo "~/go/src/repo.jazznetworks.com/vaion/vaion/cloud/scripts/patch-vms $DEPLOYMENT $COMPONENT $DMP" "$@"

~/go/src/repo.jazznetworks.com/vaion/vaion/cloud/scripts/patch-vms "$DEPLOYMENT" "$COMPONENT" "$DMP" "$@"