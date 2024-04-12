#!/bin/bash

if [[ "$1" == "-h" ]]; then
	echo git-push [options]
	exit 0
fi

OLD_BRANCH=$(git rev-parse --abbrev-ref HEAD)
NEW_BRANCH=$(echo $OLD_BRANCH | sed 's/^cs_//; s/-/_/g')
FORCE_OPTION="${1:---force-with-lease}"

if [[ "$FORCE_OPTION" == "simple" ]]; then
	FORCE_OPTION=""
fi

set -x 
git push $FORCE_OPTION origin "$OLD_BRANCH:cs_$NEW_BRANCH"