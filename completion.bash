#!/usr/bin/env bash

components=("mgmt" "db" "access" "norm" "streamer" "ui" "authenticator" "store" "router")
vmses=("v-cloud" "tom-not-tom-2" "feature-cc-resiliency-be" "feature-cc-resiliency" "hybrid-cloud-test")
mappingsDir=$MAPS
_passwordFile=$CCs

function _getCcNames {
	if [[ ${1:-} = proper ]]; then
		sed 's/:.*:\(.*\):.*:/\1/' $_passwordFile
	elif [[ ${1:-} = vms ]]; then
		sed 's/:.*:.*:\(.*\):/\1/' $_passwordFile | uniq
	else
		sed 's/:\(.*\):.*:.*:/\1/' $_passwordFile
	fi
}

# Completion functions cannot do [[ -f ]] on paths starting with '~/'
# _parseFile changes ~/ in $1 to the absolute path.
function _parseFile {
	file=$1
	echo ${file/~\//\/home\/lightningman\/}
}

# Get cached VMS names. Returns an array.
function __getVmsNames {
	local array
	for f in $mappingsDir/*; do
		array+=($(basename $f))
	done
	echo "${array[*]}"
}

# Args:
#   - 1 = Name of VMS
function __getVmsIDs {
	local array
	while read id; do
		array+=($(echo $id | cut -d':' -f 2))
	done < <(cat $mappingsDir/$1)
	echo "${array[*]}"
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

__cc-action_completions()
{
	# disable default completion
	compopt +o default

	considering=$((COMP_CWORD-1))
	prevOption=${COMP_WORDS[considering]} # Last full word before cursor given
	lastWord=${COMP_WORDS[COMP_CWORD]}	  # Last word before cursor, even if it isn't finished

	[[ $COMP_CWORD = 1 ]] && COMPREPLY=($(compgen -W "$(_getCcNames)" -- "$lastWord")) && return

	case $prevWord in
		--detail)
			# This mode does nothing else, so it allows no other arguments
			COMPREPLY=()
			;;
		-db|-nodb)
			# Port number
			COMPREPLY=()
			;;
		-t)
			# Tail number
			COMPREPLY=()
			;;
		-sh|--patch)
			# TODO What about platform?
			COMPREPLY=($(compgen -W "${components[*]}" -- "$lastWord"))
			;;
		--reboot)
			COMPREPLY=($(compgen -W "platform ${components[*]}" -- "$lastWord"))
			;;
		*)
			COMPREPLY=($(compgen -W "--detail -ha -h -v -l -db -nodb -t --no-map -f -p --patch --reboot -sh platform ${components[*]}" -- "$lastWord"))
			;;
	esac
}
complete -F __cc-action_completions cc-action.sh

__hawatch_completions()
{
	# disable default completion
	compopt +o default

	lastWord=${COMP_WORDS[COMP_CWORD]}	  # Last word before cursor, even if it isn't finished
	prevOption=${COMP_WORDS[$((COMP_CWORD-1))]} # Last full word before cursor given
	
	if [[ $COMP_CWORD = 1 ]]; then
		compopt -o default
		# Complete stored cloud connectors
		COMPREPLY=($(compgen -W "$(_getCcNames)" -- "$lastWord"))
		# Also complete files. Which will be used determines what mode hawatch will run in.
		COMPREPLY+=($(compgen -W "$(find $(dirname $(_parseFile ${lastWord:-.})) -type f -maxdepth 1 -printf '%P\n' 2>/dev/null)" -- "$lastWord"))
	elif [[ $prevOption = --map ]]; then
		COMPREPLY=($(compgen -W "$(find $mappingsDir -maxdepth 1 -printf '%P\n' 2>/dev/null)" -- "$lastWord"))
	elif [[ $COMP_CWORD = 2 ]]; then
		COMPREPLY=($(compgen -W "${components[*]} --map --no-map" -- "$lastWord"))
	else
		common=( "-run" "-file" "-cc" "-h" "--help" "--debug" "--no-map" "--map" )
		if [[ -f $(_parseFile ${COMP_WORDS[1]}) ]]; then
			# Running in file mode unlocks the -l (less -S) option.
			common+=("-l")
		fi
		COMPREPLY=($(compgen -W "${common[*]}" -- "$lastWord"))
	fi
}
complete -F __hawatch_completions hawatch

__vms-action_completions()
{
	# disable default completion
	compopt +o default

	considering=$((COMP_CWORD-1))
	prevOption=${COMP_WORDS[considering]} # Last full word before cursor given
	lastWord=${COMP_WORDS[COMP_CWORD]} # Last word before the cursor, even if it isn't finished

	if [[ $COMP_CWORD = 1 ]]; then
		COMPREPLY=($(compgen -W "$(__getVmsNames)" -- "$lastWord"))
	elif [[ $prevOption = --patch ]]; then
		COMPREPLY=($(compgen -W "${components[*]}" -- "$lastWord"))
	elif [[ $prevOption = -t ]] || [[ $prevOption = -c ]] || [[ $prevOption = -n ]] || [[ $prevOption = --curl ]]; then
		echo "nothing"
		:
	elif [[ $prevOption = PUT || $prevOption = CREATE ]]; then
		echo "curl data"
		:
	elif [[ ${COMP_WORDS[2]} = --curl ]]; then
		COMPREPLY=($(compgen -W "delete put create get -v -p" -- "$lastWord"))
	else
		# This comment is here because tree sitter has a problem for some reason
		# if it isn't.
		common=("-t" "-l" "-n" "-c" "-h" "--help" "--patch" "-db" "--debug" "--no-map" "--curl" "--version")
		if [[ $COMP_CWORD = 2 ]]; then
			common+=("${components[*]}")
		fi
		COMPREPLY=($(compgen -W "${common[*]}" -- "$lastWord"))
	fi
}
complete -F __vms-action_completions vms-action.sh

__get-cookie_completions()
{
	# disable default completion
	compopt +o default

	lastWord=${COMP_WORDS[COMP_CWORD]} # Last word before the cursor, even if it isn't finished

	COMPREPLY=($(compgen -W "$(__getVmsNames)" -- "$lastWord"))
}
complete -F __get-cookie_completions get-cookie

__construct-name-mappings_complections()
{
	compopt +o default

	lastWord=${COMP_WORDS[COMP_CWORD]}
	prevOption=${COMP_WORDS[$((COMP_CWORD-1))]}

	case $prevOption in
		-vms)
			COMPREPLY=($(compgen -W "$(__getVmsNames)" -- "$lastWord"))
			;;
		-s|--source)
			compopt -o default
			;;
		--context)
			COMPREPLY=()
			;;
		*)
			COMPREPLY=($(compgen -W "-vms -s --source --context" -- "$lastWord"))
			;;
	esac
}
complete -F __construct-name-mappings_complections construct-name-mappings.sh

__get-cc-spec_complections()
{
	gets=("--get-ip" "--get-name" "--get-vms" "--get-proper-name" "--get-password")
	sets=("--new" "--store-name" "--store-proper-name" "--store-vms")
	params=("-c" "--cloud-connector" "--proper-name" "--vms")
	other=("-h" "--help" "--debug")

	prevWord=${COMP_WORDS[$((COMP_CWORD-1))]}
	lastWord=${COMP_WORDS[$COMP_CWORD]}

	case $prevWord in
		-c|--cloud-connector)
			COMPREPLY=($(compgen -W "$(_getCcNames)" -- "$lastWord"))
			;;
		--proper-name)
			COMPREPLY=($(compgen -W "$(_getCcNames proper)" -- "$lastWord"))
			;;
		--vms)
			COMPREPLY=($(compgen -W "$(_getCcNames vms)" -- "$lastWord"))
			;;
		--new|--store-name|--store-proper-name|--store-vms)
			COMPREPLY=()
			;;
		*)
			COMPREPLY=($(compgen -W "${gets[*]} ${sets[*]} ${params[*]} ${others[*]}" -- "$lastWord"))
			;;
	esac
}
complete -F __get-cc-spec_complections get-cc-spec.sh

__clusterLog_completions() {
	lastWord=${COMP_WORDS[$COMP_CWORD]}
	
	case $COMP_CWORD in
		1)
			COMPREPLY=($(compgen -W "$(while read p; do [[ ! -z $p ]] && __printNumberWord $p; done < <(find ~/cluster/ -type d -maxdepth 1 -printf '%P\n' 2>/dev/null))" -- "$lastWord"))
			;;
		*)
			dir=${COMP_WORDS[1]}
			COMPREPLY=($(compgen -W "$(while read p; do echo $p | sed 's/.txt//'; done < <(find ~/cluster/`__printWordNumber $dir`/ -name "*.txt" -printf '%P\n' 2>/dev/null))" -- "$lastWord"))
			;;
	esac
}
complete -F __clusterLog_completions clusterLog

__dbCluster_completions()
{
	lastWord=${COMP_WORDS[$COMP_CWORD]}
	
	case $COMP_CWORD in
		1)
			COMPREPLY=($(compgen -W "$(while read p; do [[ ! -z $p ]] && __printNumberWord $p; done < <(find ~/cluster/ -type d -maxdepth 1 -printf '%P\n' 2>/dev/null))" -- "$lastWord"))
			;;
		*)
			COMPREPLY=($(compgen -W "remote local" -- "$lastWord"))
			;;
	esac
}
complete -F __dbCluster_completions dbCluster

__map-IDs_completions()
{
	prevWord=${COMP_WORDS[$((COMP_CWORD-1))]}
	lastWord=${COMP_WORDS[$COMP_CWORD]}
	
	if [[ $prevWord = --reverse ]]; then
		vmsName=${COMP_WORDS[$((COMP_CWORD-2))]}
		COMPREPLY=($(compgen -W "$(__getVmsIDs $vmsName)" -- "$lastWord"))
	elif [[ $COMP_CWORD = 1 ]]; then
		COMPREPLY=($(compgen -W "$(__getVmsNames)" -- "$lastWord"))
	else
		COMPREPLY=($(compgen -W "--reverse" -- "$lastWord"))
	fi
}
complete -F __map-IDs_completions map-IDs.sh