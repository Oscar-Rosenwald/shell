#!/usr/bin/env bash

set -xeuo pipefail
IFS=$'\n\t'

file=~/Private/passwords/aws

printHelp () {
cat <<EOF
$0 <1-4|ip> [-n] [component] [-p password] [-f file] [user]

If password is given, store it in file. -n mean get new password and store it.

Defaults:
- file      = $file
- user      = admin
- component = mgmt
EOF
}

password=
forceNoPassword=false
user=
component=
which=
new=false # If true, get new password for the CC.

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		-p)
			password="$2"
			if [[ -z "$password" ]]; then
				forceNoPassword=true
			fi
			shift
			;;
		-f)
			file="$2"
			shift
			;;
		-n)
			new=true
			;;
		-h|--help)
			printHelp
			exit 0
			;;
		*)
			if [[ -z "$which" ]]; then
				which="$1"
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

if [[ ! -z $password ]]; then
	get_cc_spec.sh -c $which -p $password
fi

# Check if we're getting a new password
if [[ $new = true ]]; then
	new='--no-cache'
else
	new=
fi

which=$(get_cc_spec.sh --get-ip -c $which)
usePassword=$(get_cc_spec.sh -c $which $new)
echo "Using IP $which and password '$usePassword'"

function patch {
	build-docker-component.sh $component

	file="/tmp/${component}_image.tgz"
	tag="bazel/go/vms/$component:${component}_image"

	sshpass -p $usePassword scp "$file" "$user@$which:/tmp/"
	sshpass -p $usePassword ssh "$user@$which" -C "shell -c \"docker-compose rm -f -s $component && docker load -i $file && rm $file && docker tag $tag $component:latest && docker-compose up -d $component\""
}

if [[ ! -z "$usePassword" ]] && [[ $forceNoPassword = false ]]; then
	patch
else
	update_component_docker.sh $which $component $user
fi