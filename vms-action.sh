#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

printHelp() {
cat <<EOF
$0 <vms-name> [ <component> [-t num] [-l] | -db | --patch <component> ] [-c <context>] [-n <namespace>]

Perform commmon VMS actions.

component           Log from this component and follow the log. Default is mgmt.
-t                  Log this many lines. Default is 500.
-l                  Don't follow the log, but display it in 'less' fashion.

-db                 Log into the database of the VMS.

--patch <component> Patch this component. Default is mgmt.

-c <context>        Use this context. Default is aw1.
-n <namespace>      Use this namespace. Default is prod. Leave out clouddemo-vcloud-.
EOF
}

namespace=clouddemo-vcloud-prod
context=aw1
whatToDo=log
vms=
follow=true
tail=500

while [[ $# -gt 0 ]]; do
	case $1 in
		-db)
			whatToDo=db
			;;
		--path)
			whatToDo=patch
			;;
		-c)
			context=$2
			shift
			;;
		-n)
			namespace=clouddemo-vcloud-$2
			shift
			;;
		-l)
			follow=false
			;;
		-t)
			tail=$2
			shift
			;;
		-h|--help)
			printHelp
			exit 0
			;;
		*)
			if [[ -z $vms ]]; then
				vms=$1
			else
				component=$1
			fi
			;;
	esac
	shift
done

([[ $whatToDo = log ]] | [[ $whatToDo = patch ]]) && [[ -z ${component+x} ]] && component=mgmt

__getPodName() {
	g="-v"
	[[ ${1:-} = db ]] && g=''

	depInternalName=$(kubectl --context=$context --namespace=$namespace get ingress | grep $vms | cut -d ' ' -f 1)
	echo $(kubectl --context=$context --namespace=$namespace get pods | grep $depInternalName | grep $g '\-db-' | head -n 1 | cut -d ' ' -f 1)
}

case $whatToDo in
	db)
		pod=$(__getPodName db)
		set -x
		kubectl -n $namespace exec -it $pod --context=$context --container db -- psql -U postgres -d vaionmgmt
		;;
	log)
		pod=$(__getPodName)
		if [[ $follow = true ]]; then
			set -x
			kubectl logs --context=$context --namespace=$namespace $pod -f --tail=$tail $component $@
		else
			set -x
			kubectl logs --context=$context --namespace=$namespace $pod --tail=$tail $component $@ | less
		fi
		;;
	patch)
		set -x
		$VAION_PATH/go/cloud/scripts/patch-vms $vms $component ${namespace/clouddemo_vcloud_/} --context=$context $@
		;;
	*)
		echo "Unrecognised operation $whatToDo"
		printHelp
		exit 1
		;;
esac
		