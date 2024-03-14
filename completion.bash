#!/usr/bin/env bash

components=("mgmt" "db" "access" "norm" "streamer" "ui" "authenticator" "store" "router")

_branch_completions()
{
	index=${#COMP_WORDS[@]}
	index=$((index-2))
	# echo "index: $index; word: ${COMP_WORDS[$index]}"

	if [ "${COMP_WORDS[$index]}" == "-s" ]; then
		index=$((index+1))
		COMPREPLY=($(compgen -W "free active reserved pipeline long-term" -- "${COMP_WORDS[$index]}"))
	else
		if [ "${#COMP_WORDS[@]}" -ge 4 ]; then
			return
		else
			index=$((index+1))
			mapfile -t aa < <(git for-each-ref --shell   --format='%(refname)'   refs/heads/ | sed -e "s_refs/heads/__" | sed -e "s/'//g")
			COMPREPLY=($(compgen -W "$(echo ${aa[*]})" -- "${COMP_WORDS[$index]}"))
		fi
	fi
}
complete -F _branch_completions b # execute after every 'branch' request

_analyse_logs_completions()
{
	wholeIndex=${#COMP_WORDS[@]}
	checkIndex=$((wholeIndex-2))
	index=$((wholeIndex-1))

	if [[ "${COMP_WORDS[$checkIndex]}" = "-f" ]]; then
		COMPREPLY=($(compgen -W "$(ls)" -- "${COMP_WORDS[$index]}"))
	elif [[ "${COMP_WORDS[$checkIndex]}" = "-w" ]]; then
		COMPREPLY=($(compgen -W "restarts panics start end first current both full" -- "${COMP_WORDS[$index]}"))
	fi
}

complete -F _analyse_logs_completions analyse_logs.sh

_awssh_completions()
{
	# at the top of the function to disable default
	compopt +o default

	considering=$((COMP_CWORD-1))
	lastOption=${COMP_WORDS[considering]}
	lastWord=${COMP_WORDS[COMP_CWORD]}
	file=~/Private/passwords/aws

	next=false
	for arg in ${COMP_WORDS[@]}; do
		if [[ $next = true ]]; then
			file=${arg/~\//\/home\/lightningman\/}
			break
		fi
		if [[ $arg = "-f" ]]; then
			next=true
		fi
	done

	if [[ $lastOption = -f ]]; then
		compopt -o default # reenable default completion
		COMPREPLY=()
	elif [[ -f $file ]]; then
		if [[ $lastOption = -p ]]; then
			COMPREPLY=($(compgen -W "$(sed 's/.*:\(.*\):.*/\1/' $file)" -- "$lastWord"))
		else
			COMPREPLY=($(compgen -W "$(sed 's/.*:\(.*\):.*/\1/' $file)" -- "$lastWord"))
		fi	
	fi
}
complete -F _awssh_completions awssh

_cc-patch_completions()
{
	# disable default completion
	compopt +o default

	considering=$((COMP_CWORD-1))
	lastOption=${COMP_WORDS[considering]} # Last full word before cursor given
	lastWord=${COMP_WORDS[COMP_CWORD]}	  # Last word before cursor, even if it isn't finished
	file=~/Private/passwords/aws

	next=false
	for arg in ${COMP_WORDS[@]}; do
		if [[ $next = true ]]; then
			file=${arg/~\//\/home\/lightningman\/}
			break
		fi
		if [[ $arg = "-f" ]]; then
			next=true
		fi
	done

	if [[ $lastOption = -f ]]; then
		compopt -o default # reenable default completion to search for files
		COMPREPLY=()
	elif [[ -f $file ]]; then
		if [[ $lastOption = -p ]] || [[ -f ${lastOption/~\//\/home\/lightningman\/} ]] || [[ $lastOption = cc-patch.sh ]]; then
			COMPREPLY=($(compgen -W "$(sed 's/.*:\(.*\):.*:.*/\1/' $file)" -- "$lastWord"))
		else
			COMPREPLY=($(compgen -W "-h -p -f ${components[*]}" -- "$lastWord"))
		fi	
	fi
}
complete -F _cc-patch_completions cc-patch.sh

__cc-action_completions()
{
	# disable default completion
	compopt +o default

	considering=$((COMP_CWORD-1))
	lastOption=${COMP_WORDS[considering]} # Last full word before cursor given
	lastWord=${COMP_WORDS[COMP_CWORD]}	  # Last word before cursor, even if it isn't finished
	file=~/Private/passwords/aws

	next=false
	for arg in ${COMP_WORDS[@]}; do
		if [[ $next = true ]]; then
			file=${arg/~\//\/home\/lightningman\/}
			break
		fi
		if [[ $arg = "-f" ]]; then
			next=true
		fi
	done

	if [[ $lastOption = -f ]]; then
		compopt -o default
		COMPREPLY=()
	elif [[ -f $file ]]; then
		if [[ $lastOption = -p ]] || [[ -f ${lastOption/~\//\/home\/lightningman\/} ]] || [[ $lastOption = cc-action.sh ]]; then
			COMPREPLY=($(compgen -W "$(sed 's/.*:\(.*\):.*:.*/\1/' $file)" -- "$lastWord"))
		elif [[ $lastOption = -t ]]; then
			# Enter number to tail.
			COMPREPLY=()
		elif [[ $lastOption = -sh ]]; then
			COMPREPLY=($(compgen -W "${components[*]}" -- "$lastWord"))
		else
			COMPREPLY=($(compgen -W "-h -db -nodb -t -f -p -sh ${components[*]}" -- "$lastWord"))
		fi	
	fi
}
complete -F __cc-action_completions cc-action.sh