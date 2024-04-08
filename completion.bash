#!/usr/bin/env bash

components=("mgmt" "db" "access" "norm" "streamer" "ui" "authenticator" "store" "router")
_passwordFile=~/Private/passwords/aws

# Completion functions cannot do [[ -f ]] on paths starting with '~/'
# _parseFile changes ~/ in $1 to the absolute path.
function _parseFile {
	file=$1
	echo ${file/~\//\/home\/lightningman\/}
}

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

	lastWord=${COMP_WORDS[COMP_CWORD]}

	[[ $COMP_CWORD = 1 ]] && COMPREPLY=($(compgen -W "$(sed 's/.*:\(.*\):.*:.*/\1/' $_passwordFile)" -- "$lastWord"))
}
complete -F _awssh_completions awssh

_cc-patch_completions()
{
	# disable default completion
	compopt +o default

	lastWord=${COMP_WORDS[COMP_CWORD]}	  # Last word before cursor, even if it isn't finished

	if [[ $COMP_CWORD = 1 ]]; then
		COMPREPLY=($(compgen -W "$(sed 's/.*:\(.*\):.*:.*/\1/' $_passwordFile)" -- "$lastWord"))
	else
		COMPREPLY=($(compgen -W "-h -p -f ${components[*]}" -- "$lastWord"))
	fi	
}
complete -F _cc-patch_completions cc-patch.sh

__cc-action_completions()
{
	# disable default completion
	compopt +o default

	considering=$((COMP_CWORD-1))
	prevOption=${COMP_WORDS[considering]} # Last full word before cursor given
	lastWord=${COMP_WORDS[COMP_CWORD]}	  # Last word before cursor, even if it isn't finished

	if [[ $COMP_CWORD = 1 ]]; then
		COMPREPLY=($(compgen -W "$(sed 's/.*:\(.*\):.*:.*/\1/' $_passwordFile)" -- "$lastWord"))
	elif [[ $prevOption = -t ]]; then
		# Enter number to tail.
		COMPREPLY=()
	elif [[ $prevOption = -sh ]]; then
		COMPREPLY=($(compgen -W "${components[*]}" -- "$lastWord"))
	else
		COMPREPLY=($(compgen -W "-ha -h -db -nodb -t -f -p -sh ${components[*]}" -- "$lastWord"))
	fi	
}
complete -F __cc-action_completions cc-action.sh

__get_cc_spec_completions()
{
	# disable default completion
	compopt +o default

	considering=$((COMP_CWORD-1))
	prevOption=${COMP_WORDS[considering]} # Last full word before cursor given
	lastWord=${COMP_WORDS[COMP_CWORD]}	  # Last word before cursor, even if it isn't finished

	case $prevOption in
		-c|-cc|--cc|--cloud-connector)
			COMPREPLY=($(compgen -W "$(sed 's/.*:\(.*\):.*:.*/\1/' $_passwordFile)" -- "$lastWord"))
			;;
		-f|--file)
			compopt -o default
			COMPREPLY=()
			;;
		*)
			COMPREPLY=($(compgen -W "-h --help --no-cache -p --password -vms --n -vms-name --store-ip -f --file --cc-name -c --cloud-connector" -- "$lastWord"))
			;;
	esac
}
complete -F __get_cc_spec_completions get_cc_spec.sh

__hawatch_completions()
{
	# disable default completion
	compopt +o default

	lastWord=${COMP_WORDS[COMP_CWORD]}	  # Last word before cursor, even if it isn't finished

	if [[ $COMP_CWORD = 1 ]]; then
		compopt -o default
		# Complete stored cloud connectors
		COMPREPLY=($(compgen -W "$(sed 's/.*:\(.*\):.*:.*/\1/' $_passwordFile )" -- "$lastWord"))
		# Also complete files. Which will be used determines what mode hawatch will run in.
		COMPREPLY+=($(compgen -W "$(find $(dirname $(_parseFile ${lastWord:-.})) -maxdepth 1 -printf '%P\n')" -- "$lastWord"))
	elif [[ $COMP_CWORD = 2 ]]; then
		COMPREPLY=($(compgen -W "${components[*]}" -- "$lastWord"))
	else
		common=("-run" "-file" "-cc -h --help")
		if [[ -f $(_parseFile ${COMP_WORDS[1]}) ]]; then
			# Running in file mode unlocks the -l (less -S) option.
			common+=("-l")
		fi
		COMPREPLY=($(compgen -W "${common[*]}" -- "$lastWord"))
	fi
}
complete -F __hawatch_completions hawatch