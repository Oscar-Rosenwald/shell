#!/usr/bin/env bash

set -euo pipefail

# STATUS:
# - Free: No task, free to use
# - Reseved: Planning to use for task, but not used yet
# - Active: Is actively used for a task
# - Pipeline: Task is pushed, but not merged
# - Long-term: Is continuously being used by a large task or a task long in approval

file=~/Private/cache/branches.csv
# Denotes the VMS name to whose commit I checked out. Ignored if the current commit doesn't match the recorded commit.
# Format: VMS-name,commit
currentFile=~/Private/cache/current-commit-vms
options=("free" "reserved" "active" "pipeline" "long-term")
currentBranch=$(git branch --list | grep "\*" | sed 's/\* //')
whatToDo=listAll  # listAll / list / free / update / add
newStatus=
newTask=
RESET=reset
useLocalBranch=false

function __printHelp() {
cat <<EOF
b [-n] <branch name>
  [-d] [branch name]
  [branch name] [OPTIONS]...

list/edit branch usage

-n  Add new branch and create it. Default state is 'reserved'
-d  Delete the task - leave it blank, and set status to 'free'

-s  Update state to one of 'free reserved active pipeline long-term'
-t  Update the task this branch is used for
-nt Alias of "-s active -t"
-pt Alias of "-s pipeline -t"

Simply writing the branch name will show usage of that branch. Leaving branch out defaults to current branch during updating mode.
Using `this` as branch name defaults to this one during displaying mode.
EOF
}

# 1: status
function __isValidOption() {
	option=$1
	if [[ ! " ${options[*]} " =~ " ${option} " ]]; then
		echo "Option '$option' is not valid. Use 'free | reserved | active | pipeline | long-term'"
		exit 1
	fi
}

# 1: branch name
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

# Uses $file
function __list {
	RED=$(tput setaf 1) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3) PURPLE=$(tput setaf 125)
	BLUE=$(tput setaf 4) WHITE=$(tput setaf 7)
	NC=$(tput sgr0)

	branchSize=0
	index=0
	useCurrentBranch=false

	# Add the current commit if we checked out a VMS version. Only do this if
	# we're not asking for a specific branch (AKA when $file has more than one
	# line), and when the cached commit matches the current commit.
	if [[ -f $currentFile && $(cat $file | wc -l) -gt 1 ]]; then
		line=$(cat $currentFile)
		vmsName=$(echo $line | cut -d, -f 1)
		commit=$(echo $line | cut -d, -f 2)
		if [[ $commit = $(git rev-parse --short HEAD) ]]; then
			branch[$index]=current
			status[$index]=${RED}active${NC}
			task[$index]="Check out VMS $vmsName"
			branchSize=7
			index=1
			useCurrentBranch=true
		fi
	fi

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

	for i in `seq 0 $index`; do
		branch="${branch[$i]}"
		tmpBranchSize="$branchSize"
		if [[ $branch = current && $useCurrentBranch = true ]] || [[ "$branch" == "$currentBranch" ]]; then
			branch="$PURPLE$branch$NC"
			tmpBranchSize=$((branchSize+17))
		fi
		printf '%'"$tmpBranchSize"'s: %-23s%s\n' "$branch" "${status[$i]}" "${task[$i]}"
	done
}

# 1: Name of new branch
# Set no status/task. Done separately.
function __add {
	branch="$1"
	status="${options[0]}"

	if grep -q "^$branch," $file; then
		echo "$branch is already in file"
		exit 1
	fi

	if ! __branchExists "$branch"; then
		git co -b "$branch"
	fi

	echo "$branch,$status" >> $file
}

# 1: $status
# 2: $task
# Uses $currentBranch
# Uess $file
function __update {
	status="$1"
	task="$2"

	if ! grep -q "^$currentBranch," $file; then
		echo "Updating branch $currentBranch which doesn't exist"
		exit 1
	fi

	branchLog=$(grep "^$currentBranch," $file)
	currentStatus=$(echo $branchLog | cut -d, -f2)
	currentTask=$(echo $branchLog | cut -d, -f3) # could be empty

	if [[ $status = $RESET ]]; then
		status=",${options[0]}"
	elif [[ -z $status ]]; then
		status=","$currentStatus
	else
		status=","$status
	fi

	if [[ "$task" = $RESET ]]; then
		task=
	elif [[ -z "$task" ]]; then
		task=","$currentTask
	else
		task=","$task
	fi

	sed -i "s/^$currentBranch,$currentStatus.*$/$currentBranch$status$task/" $file

	b $currentBranch
}

# ========================
# ========= CODE =========
# ========================

if [[ -z "${1:-}" ]]; then
	__list
	exit 0
fi

while [[ "$#" -gt 0 ]]; do
	opt="$1"
	shift

	case "$opt" in
		-n)
			currentBranch="$1"
			whatToDo=add
			shift
			;;
		-h|--help)
			__printHelp
			exit 0
			;;
		-d)
			whatToDo=free
			;;
		-s)
			newStatus="$1"
			__isValidOption "$newStatus"
			whatToDo=update
			shift
			;;
		-t)
			newTask="$1"
			whatToDo=update
			shift
			;;
		-nt)
			newTask="$1"
			newStatus="active"
			__isValidOption "$newStatus"
			whatToDo=update
			shift
			;;
		-pt)
			newTask="$1"
			newStatus="pipeline"
			__isValidOption "$newStatus"
			whatToDo=update
			shift
			;;
		-*)
			echocolour "Unknown option $opt"
			echo
			__printHelp
			exit 1
			;;
		*)
			if [[ "$opt" = "this" ]]; then
				useLocalBranch=true
			else
				currentBranch="$opt"
			fi
			whatToDo=list
			;;
	esac
done

case $whatToDo in
	listAll)
		__list
		;;

	list)
		grep "^ *$currentBranch," "$file" > "$file.tmp"
		file="$file.tmp"
		__list
		rm "$file"
		;;
	
	add)
		__add "$currentBranch"
		if [[ ! -z "$newStatus" ]] || [[ ! -z "$newTask" ]]; then
			__update "$newStatus" "$newTask"
		fi
		;;

	free)
		__update $RESET $RESET
		;;

	update)
		if [[ -z "$newStatus" ]] && [[ -z "$newTask" ]]; then
			__printHelp
			exit 1
		fi

		__update "$newStatus" "$newTask"
		;;
	*)
		echo "Something went very wrong -- check the script"
		;;
esac
