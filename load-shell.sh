#!/usr/bin/env bash

# This script loads all variables, functions, and completions from the shell
# repository. Use `source <this-file>` in your .bashrc.

export MAPS=~/Private/cache/mappings
export CCs=~/Private/cache/CCs
export SHELL_DIR=~/shell-all/merged
export COMMON_DIR=$SHELL_DIR/common
export WORK_DIR=$SHELL_DIR/work
export HOME_DIR=$SHELL_DIR/home
export UTILS_DIR=$WORK_DIR/utils

[[ -f $COMMON_DIR/updir_func ]] && . $COMMON_DIR/updir_func
[[ -f $COMMON_DIR/completion.bash ]] && . $COMMON_DIR/completion.bash
[[ -f $WORK_DIR/resiliency_functions ]] && . $WORK_DIR/resiliency_functions
[[ -f $WORK_DIR/cluster ]] && . $WORK_DIR/cluster

function addDirToPath() {
	topLevelDir=$1
	for fileOrDir in $topLevelDir/*; do
		# We want to avoid adding work/utils/ to PATH. It's a place that
		# contains scripts which are only called by other scripts, and we
		# therefore don't want them to clutter up completion.
		if [[ -d $fileOrDir && $(realpath $fileOrDir) != $WORK_DIR/utils ]]; then
			PATH="$PATH:$topLevelDir/"
			addDirToPath $fileOrDir
		fi
	done
}

addDirToPath $SHELL_DIR
source $SHELL_DIR/common-functions.sh