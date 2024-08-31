#!/usr/bin/env bash

# This script loads all variables, functions, and completions from the shell
# repository. Use `source <this-file>` in your .bashrc.
#
# Always source .bash_variables before this script.

if [[ $WORK_COMPUTER = true ]]; then
	[[ -f $WORK_DIR/resiliency_functions ]] && . $WORK_DIR/resiliency_functions
	[[ -f $WORK_DIR/cluster ]] && . $WORK_DIR/cluster

	if [[ -d $VOLTA_HOME ]]; then
		PATH="$VOLTA_HOME/bin:$PATH"
		PATH=$BUN_INSTALL/bin:$PATH
	fi

	[[ -d $HOME/GoLand/bin/ ]] && PATH="$PATH:~/GoLand/bin/"
	[[ -d $VAION_PATH/scripts ]] && PATH="$PATH:$VAION_PATH/scripts:$VAION_PATH/scripts/ha"
	[[ -d $VAION_PATH/../toolset/scripts/ ]] && PATH="$PATH:$VAION_PATH/../toolset/scripts"
	[[ -d /usr/bin ]] && PATH="/usr/bin:$PATH"
else
	export VISUAL="vim"
	if [[ -d $HOME_DIR ]]; then
		. $HOME_DIR/filmList
		. $HOME_DIR/bookList
		. $HOME_DIR/screenshot
		. $HOME_DIR/phones
		. $HOME_DIR/webpgif
		. $HOME_DIR/memoryOut
		. $HOME_DIR/inspiration
		. $HOME_DIR/set-background
	fi
	if [[ -d $MAGIC_DIR ]]; then
		PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/Library/TeX/texbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:$MAGIC_DIR/scripts
	fi
fi

# Load common scripts
[[ -f $COMMON_DIR/updir_func ]] && . $COMMON_DIR/updir_func
[[ -f $COMMON_DIR/completion.bash ]] && . $COMMON_DIR/completion.bash


function addDirToPath() {
	topLevelDir=$1
	for fileOrDir in $topLevelDir/*; do
		# We want to avoid adding work/utils/ to PATH. It's a place that
		# contains scripts which are only called by other scripts, and we
		# therefore don't want them to clutter up completion.
		if [[ -d $fileOrDir && $(realpath $fileOrDir) != $UTILS_DIR ]]; then
			PATH="$PATH:$fileOrDir"
			addDirToPath $fileOrDir
		fi
	done
}

addDirToPath $SHELL_DIR

if [[ $WORK_COMPUTER = true ]]; then
	source $SHELL_DIR/common-work-functions.sh
else
	source $SHELL_DIR/common-home-functions.sh
fi