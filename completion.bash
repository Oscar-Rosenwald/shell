#!/usr/bin/env bash

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