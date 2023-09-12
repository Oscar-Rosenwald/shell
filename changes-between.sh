#!/bin/bash 
set -euo pipefail

extract_applicationSha () {
echo "$1" | sed 's/^.*applicationSha\"\:\"\(.*\)\"\,\"applicationVersion.*$/\1/'
}
		
if [[ $# -ne 2 ]] ; then
        echo "Usage: $0 <from release> <to release>"
        exit 0
fi

from_manifest=$(curl --no-progress-meter https://dmp.avasecurity.com/api/v1/upgradeManifest?channel="$1")
from_applicationSha=$(extract_applicationSha "$from_manifest" )
to_manifest=$(curl --no-progress-meter https://dmp.avasecurity.com/api/v1/upgradeManifest?channel="$2")
to_applicationSha=$(extract_applicationSha "$to_manifest" )
branch=$(echo $1 | sed "s/release_\([0-9]*\)_\([0-9]*\)_\([0-9]*\)/release_\1_\2/")
git switch $branch
git pull
git log $from_applicationSha..$to_applicationSha 
