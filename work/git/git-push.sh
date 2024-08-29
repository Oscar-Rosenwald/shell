#!/bin/bash

if [[ "$1" == "-h" ]]; then
	echo git-push [options]
	exit 0
fi

OLD_BRANCH=$(git rev-parse --abbrev-ref HEAD)
NEW_BRANCH=cs_$(echo $OLD_BRANCH | sed 's/^cs_//; s/-/_/g')
FORCE_OPTION="${1:---force-with-lease}"

if [[ "$FORCE_OPTION" == "simple" ]]; then
	FORCE_OPTION=""
fi

if [[ $OLD_BRANCH =~ rt_.* ]]; then
	NEW_BRANCH=release_topic_${OLD_BRANCH/rt_/}
fi

cmd="git push $FORCE_OPTION origin \"$OLD_BRANCH:$NEW_BRANCH\""
echocolour $cmd
eval $cmd

if [[ $? -eq 0 ]]; then
	branches=$PRIVATE_DIR/branches.csv
	if grep -q "$OLD_BRANCH.*active" $branches; then
		b -s pipeline
	elif grep -q "$OLD_BRANCH,free" $branches; then
		read -p "What is the topic of this branch? " topic
		b -s pipeline -t "$topic"
	fi
fi