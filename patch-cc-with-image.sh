#!/usr/bin/env bash

set -xeou pipefail
IFS=$'\n\t'

function printHelp {
	cat <<EOF
Usage $0
  -h | --help
  <addr> [-c component] [-f file]

Default component is 'access'
Default file is computed like this: <component>_image.tgz
EOF
}

if [[ -z "${1:-}" ]]; then
	echo "No cloud connector address or --help option given"
	printHelp
	exit 1
fi

addr="${1:-}"
component="access"
fullfile=

while [[ "$#" -gt 0 ]]; do
	opt="$1"
	shift

	case $opt in
		-f)
			fullfile=$1
			shift
			;;
		-c) 
			component=$1
			shift
			;;
		-h|--help)
			printHelp
			exit 0
			;;
		*)
			if [[ $opt != $addr ]]; then
				echo "Invalid option $opt"
				printHelp
				exit 1
			fi
			;;
	esac
done

if [[ -z "$fullfile" ]]; then
	fullfile="${component}_image.tgz"
fi

file="/tmp/"$(basename "$fullfile")

imageTag="bazel/go/vms/${component}:${component}_image"

scp "$fullfile" "admin@$addr:/tmp/"
ssh "admin@$addr" -C "shell -c \"docker-compose rm -f -s $component && docker load -i $file && rm $file && docker tag $imageTag $component:latest && docker-compose up -d $component\""