#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

printHelp () {
cat <<EOF
$0 <ip> [component] -p password [user]

Defaults:
- user      = admin
- component = mgmt
EOF
}

user=
component=
nodeIp=
password=

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		-p)
			password="${2:-}"
			shift
			;;
		-h|--help)
			printHelp
			exit 0
			;;
		*)
			if [[ -z "$nodeIp" ]]; then
				nodeIp="$1"
			elif [[ -z "$component" ]]; then
				component="$1"
			elif [[ -z "$user" ]]; then
				user="$1"
			else
				printHelp
				exit 1
			fi
			;;
	esac
	shift
done

if [[ -z "$component" ]]; then
	component=mgmt
fi
if [[ -z "$user" ]]; then
	user=admin
fi

function patch {
	build-docker-component.sh $component

	file="/tmp/${component}_image.tgz"
	tag="bazel/go/vms/$component:${component}_image"

	set -x 

	sshpass -p $password scp "$file" "$user@$nodeIp:/tmp/"
	sshpass -p $password ssh "$user@$nodeIp" -C "shell -c \"docker-compose rm -f -s $component && docker load -i $file && rm $file && docker tag $tag $component:latest && docker-compose up -d $component\""
}

if [[ ! -z "$password" ]]; then
	patch
else
	update_component_docker.sh $nodeIp $component $user
fi