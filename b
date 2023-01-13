#!/usr/bin/env bash

set -euo pipefail

# STATUS:
# - Free: No task, free to use
# - Reseved: Planning to use for task, but not used yet
# - Active: Is actively used for a task
# - Pipeline: Task is pushed, but not merged
# - Long-term: Is continuously being used by a large task or a task long in approval

function __printHelp() {
	echo "b [-un] <branch name> [OPTIONS]..."
	echo "list/edit branch usage"
	echo

	echo "-n  Add new branch and create it. Default state is 'reserved'"
	echo "-u  Update existing branch with following OPTIONS"
	echo

	echo "-s  Update state to one of 'free reserved active pipeline long-term'"
	echo "-t  Update the task this branch is used for"
	echo "-dt Delete the task - leave it blank"
	echo

	echo "Simply writing the branch name will show usage of that branch"
}

file=~/Private/branches.csv

options=("free" "reserved" "active" "pipeline" "long-term")

function __printError() {
	kindOfError="$1"
	shift 1
	case "$kindOfError" in
		0)
			# Wrong number of arguments
		;;
		1)
			echo "Option '$option' is not valid. Use 'free | reserved | active | pipeline | long-term'"
			;;
	esac	
}

function __isValidOption() {
	option=$1
	if [[ ! " ${options[*]} " =~ " ${option} " ]]; then
		__printError 1 "$options"
		exit 1
	fi
}

function __branchExists() {
	branch="$1"

	for b in $( git branch --list | sed 's/\*//' ); do
		if [[ "$b" == "$branch" ]]; then
			return 0
		fi
	done

	echo "You gave a non-existant branch"
	return 1
}

function __add() {
	newBranch="$1"				# script will shout if not provided
	status="reserved"
	
	if grep -q "^$newBranch," $file; then
		echo "$newBranch is already in the file"
		exit 1
	fi

	shift 1
	while test $# -gt 0
	do
		case "$1" in
			-s)
				shift
				status="$1"
				__isValidOption "$1"
				;;
			-t)
				shift
				task=",$1"
				;;
		esac
		shift
	done

	echo "$newBranch,$status${task:-}" >> $file
	git co -b "$newBranch"
}

function __list() {
	RED=$(tput setaf 1) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3) PURPLE=$(tput setaf 125)
	BLUE=$(tput setaf 4) WHITE=$(tput setaf 7)
	NC=$(tput sgr0)

	branchSize=0
	index=0

	while read line; do
		branch[$index]=$(echo $line | cut -d , -f 1)
		status[$index]=$(echo $line | cut -d , -f 2)
		task[$index]=$(echo "$line" | cut -d , -f 3)

		str=${branch[$index]}
		if [ ${#str} -gt $branchSize ]; then
			branchSize=${#str}
		fi

		# Deal with colours
		if [ "${status[$index]}" == "free" ]; then
			str=${status[$index]}
			status[$index]="$GREEN$str$NC"
		elif [ "${status[$index]}" == "active" ]; then
			str=${status[$index]}
			status[$index]="$RED$str$NC"
		elif [ "${status[$index]}" == "long-term" ]; then
			str=${status[$index]}
			status[$index]="$BLUE$str$NC"
		elif [ "${status[$index]}" == "pipeline" ]; then
			str=${status[$index]}
			status[$index]="$YELLOW$str$NC"
		elif [ "${status[$index]}" == "reserved" ]; then
			str=${status[$index]}
			status[$index]="$WHITE$str$NC"
		fi

		index=$((index+1))
	done <$file

	branchSize=$((branchSize+1))
	index=$((index-1))

	currentBranch=$(git branch --list | grep "\*" | sed 's/\* //')
	
	for i in `seq 0 $index`; do
		branch="${branch[$i]}"
		tmpBranchSize="$branchSize"
		if [[ "$branch" == "$currentBranch" ]]; then
			branch="$PURPLE$branch$NC"
			tmpBranchSize=$((branchSize+17))
		fi
		printf '%'"$tmpBranchSize"'s: %-23s%s\n' "$branch" "${status[$i]}" "${task[$i]}"
	done
}

function __update() {
	branch="$1"
	__branchExists $branch

	# Check arguments
	if [[ "$2" != "-dt" ]] &&[[ "$2" != "-s" ]] && [[ "$2" != "-t" ]]; then
		echo "When updating a branch, use the '-s' or '-t' option, so there is something to actually update"
		exit 1
	fi
	if ! grep -q "^$branch," $file; then
		echo "Updating branch $branch which doesn't exist"
		exit 1
	fi

	deleteTask=0
	status="free"

	shift
	while test $# -gt 0
	do
		case "$1" in
			-s)
				shift
				status="$1"
				__isValidOption "$1"
				;;
			-t)
				shift
				task="$1"
				;;
			-dt)
				deleteTask=1
		esac
		shift
	done

	if [[ ! -z "${status+x}" ]]; then
		sed -i -r 's/^'"$branch"',[^,]+/'"$branch"','"$status"'/' $file
	fi
	if [[ ! -z "${task+x}" ]]; then
		sed -i -r 's/^'"$branch"',([^,]+).*/'"$branch"',\1,'"$task"'/' $file
	fi
	if [[ $deleteTask == 1 ]]; then
		sed -i -r 's/^'"$branch"',([^,]+).*/'"$branch"',\1/' $file
	fi

	# List this one branch
	b "$branch"
}

case "${1:-}" in
	-h)
		__printHelp
		;;
	-n)
		shift 1
		__add "$@"
		;;
	-u)
		shift 1
		__update "$@"
		;;
	*)
		if [[ $# == 0 ]]; then
			# List all branches
			__list
		else
			# List only one branch
			branch="$1"
			__branchExists $branch
			grep "^ *$branch," "$file" > "$file.tmp"
			file="$file.tmp"
			__list
			rm "$file"
		fi
		;;
esac
