#!/bin/bash

git fetch -a
git fm

if [[ -z $(git status --porcelain) ]]; then
	echo "Resetting to master"
	git reset --hard master
else
	echo "You have uncommitted changes
"
	git status
fi
	