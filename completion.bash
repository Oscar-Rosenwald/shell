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

# Prints a digit as a word. If more digits are passed, or if arg 1 isn't a
# digit, prints arg 1.
function __printNumberWord {
	case $1 in
		0) echo zero	;;
		1) echo one		;;
		2) echo two		;;
		3) echo three	;;
		4) echo four	;;
		5) echo five	;;
		6) echo six		;;
		7) echo seven	;;
		8) echo eight	;;
		9) echo nine	;;
		*) echo $1		;;
	esac
}

function __printWordNumber {
	case $1 in
		zero)	echo 0	;;
		one)	echo 1	;;
		two)	echo 2	;;
		three)	echo 3	;;
		four)	echo 4	;;
		five)	echo 5	;;
		six)	echo 6	;;
		seven)	echo 7	;;
		eight)	echo 8	;;
		nine)	echo 9	;;
		*)		echo $1 ;;
	esac
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
			COMPREPLY=($(compgen -W "-ha -h -v -l -db -nodb -t --no-map -f -p --patch --reboot -sh platform ${components[*]}" -- "$lastWord"))
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
	elif [[ $prevOption = -t ]] || [[ $prevOption = -c ]] || [[ $prevOption = -n ]]; then
		:
	else
		# This comment is here because tree sitter has a problem for some reason
		# if it isn't.
		common=("-t" "-l" "-n" "-c" "-h" "--help" "--patch" "-db" "--debug" "--no-map")
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
