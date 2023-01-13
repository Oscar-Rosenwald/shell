#!/bin/bash

_findIndex() {
	local element="$1"
	shift 1
	local array=("$@")
	echo "Looking for '$element' in '${array[@]}'" >&2

	for index in ${!array[@]}; do
		if [[ "$element" = "${array[$index]}" ]]; then
			echo $index
			return
		fi
	done
	echo -1
}

run="$VAION_PATH/scripts/run.sh"
echo "$run"

dockeredComponents=("store" "ana" "ui" "local-access" "platform" "streamer" "router" "db" "authenticator" "local-camera")
separateComponents=("norm" "mgmt")
declare -a wantToLog
declare -a noLog
componentNum=${#dockeredComponents[@]}

for arg in "$@"; do
	wantToLog+=("$arg")
done

for 
	
done
echo
echo docker-ed dockeredComponents: ${dockeredComponents[@]}
echo

for index in ${!dockeredComponents[@]}; do
	component=${dockeredComponents[$index]}
	# if [[ "$index" = 0 ]]; then
	# 	bash -c "$run $component" &
	# else 
	# 	gnome-terminal --tab -- bash -c "$run $component"
	# fi
	echo "$component"
done

read line