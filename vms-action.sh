#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

printHelp() {
cat <<EOF
$0 <vms-name> [ <component> [-t num] [-l] | -db | --patch <component> | --curl <URL tail> [delete | put/post '<data>'] [-v] [-p] | --version | -co ] [--no-map]

Perform commmon VMS actions.

component            Log from this component and follow the log. Default is mgmt.
-t                   Log this many lines. Default is 500.
-l                   Don't follow the log, but display it in 'less' fashion.

-db                  Log into the database of the VMS.

--patch <component>  Patch this component. Default is mgmt.

--curl <URL tail>... Run a curl command against the VMS. <URL tail> is what follows "/api/v1/". GET is default. PUT and POST require data WITHOUT BRACKETS!
-v                   Run verbose. If not given, we run -i (which prints the response code).

--version            Returns the VMS version.
-co                  Chceckout to the current version of the VMS. Must be in VAION_PATH.

--debug              Turn on debugging.

By default, we try to map the output's IDs onto real names. use --no-map to disable this.
EOF
}

context=
pod=
namespace=
whatToDo=log
vms=
follow=true
tail=100
debug=false
mapFile=

allowedCurlMethod=("put" "post" "get" "delete")
curlData=
curlMethod=
curlTail=
curlPrint='-w "cURL response: %{http_code}\n"'

while [[ $# -gt 0 ]]; do
	case $1 in
		--debug)
			debug=true
			;;
		--curl)
			whatToDo=curl
			curlMethod=GET
			curlTail=$2
			shift
			;;
		-db)
			whatToDo=db
			;;
		-co)
			whatToDo=checkout
			;;
		--version)
			whatToDo=version
			;;
		--no-map)
			mapFile=none
			;;
		--patch)
			whatToDo=patch
			;;
		-l)
			follow=false
			;;
		-v)
			curlPrint=-v
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
			elif [[ $whatToDo = curl ]]; then
				if [[ " ${allowedCurlMethod[@]} " =~ " ${1} " ]]; then
					curlMethod=${1^^}
				elif [[ $curlMethod = PUT || $curlMethod = POST ]]; then
					curlData="{$1}"
				else
					echo "I don't understand this CURL command: $1"
					printHelp
					exit 1
				fi
			else
				component=$1
			fi
			;;
	esac
	shift
done

if [[ $debug = true ]]; then
	set -x
fi

([[ $whatToDo = log ]] | [[ $whatToDo = patch ]]) && [[ -z ${component+x} ]] && component=mgmt

cachedFile=$MAPS/$vms

__composeCluster() {
	name=$1
	project=$2
	region=$3
	echo "gke_${project}_${region}_${name}"
}

# Keep aw1 first in the array so it's the first one we try. Most VMSs we'll
# interact with will be in that context.
clusters=(
		  $(__composeCluster "amazing-witch-1" "amazing-witch" "europe-west1")
		  $(__composeCluster "lively-falcon-1" "lively-falcon" "us-central1")
		  $(__composeCluster "lively-falcon-2" "lively-falcon" "europe-west1")
		  $(__composeCluster "lively-falcon-3" "lively-falcon" "australia-southeast1")
		  $(__composeCluster "lively-falcon-4" "lively-falcon" "us-west1")
		  $(__composeCluster "lively-falcon-5" "lively-falcon" "northamerica-northeast1")
		  $(__composeCluster "lively-falcon-6" "lively-falcon" "europe-west2")
		  $(__composeCluster "lively-falcon-7" "lively-falcon" "us-central1")
		  $(__composeCluster "lively-falcon-8" "lively-falcon" "europe-west1")
		  $(__composeCluster "lively-falcon-9" "lively-falcon" "europe-west3")
		  $(__composeCluster "lively-falcon-10" "lively-falcon" "northamerica-northeast1")
		  $(__composeCluster "lively-falcon-11" "lively-falcon" "us-west1")
		  $(__composeCluster "lively-falcon-12" "lively-falcon" "us-central1")
		  $(__composeCluster "lively-falcon-13" "lively-falcon" "northamerica-northeast1")
		 )

__getVmsConfig() {
	if [[ ! -f $cachedFile ]]; then
		return
	fi

	key=$1
	value=
	if grep -q "^$key:" $cachedFile; then
		value=$(grep "^$key:" $cachedFile | cut -d ':' -f 2)
	fi
	echo $value
}

__storeVmsConfig() {
	key=$1
	value=$2

	if [[ -f $cachedFile ]] && grep -q "^$key:" $cachedFile; then
		sed -i "s/$key:.*/$key:$value/" $cachedFile
	else
		echo "$key:$value" >> $cachedFile
	fi
}

# Upon exit, $context, $pod, and $namespace are filled in and cached, provided
# that they weren't cached already, or if they were that they weren't overridden
# by command-line arguments.
#
# Args:
#   - 1: If 'db', gets the db pod.
__fillVmsKubeConfig() {
	context=$(__getVmsConfig "Context")
	pod=$(__getVmsConfig "Pod")
	namespace=$(__getVmsConfig "Namespace")
	arg=${1:-}

	if [[ -z $context || -z $namespace ]]; then
		echo -n "Finding VMS context and namespace..."
		for cluster in ${clusters[*]}; do
			column=$(kubectl get ingress --context=$cluster --all-namespaces -o wide | grep $vms || echo '' )
			if [[ ! -z $column ]]; then
				namespace=$(echo $column | cut -d ' ' -f 1)
				context=$cluster
				break
			fi
		done
		echo "Done"
	fi

	if [[ -z $context || -z $namespace ]]; then
		echo "Failed to find VMS $vms in any context" >&2
		exit 1
	fi

	if [[ -z $pod ]] || [[ ! -z $arg ]]; then
		echo -n "Finding VMS pod name..."
		g="-v"
		[[ $arg = db ]] && g=''

		depInternalName=$(kubectl --context=$context --namespace=$namespace get ingress | grep "$vms\." | cut -d ' ' -f 1)
		pod=$(kubectl --context=$context --namespace=$namespace get pods | grep $depInternalName | grep $g '\-db-' | head -n 1 | cut -d ' ' -f 1)
		echo "Done"
	fi

	if [[ -z $pod ]]; then
		echo "Failed to find pod for VMs $vms in context $context and namespace $namespace" >&2
		exit 0
	fi

	__storeVmsConfig "Context" $context
	__storeVmsConfig "Namespace" $namespace
	if [[ -z $arg ]]; then 
		__storeVmsConfig "Pod" $pod
	fi
}

__getVersion() {
	__fillVmsKubeConfig
	userData=$(kubectl get pod $pod -n $namespace --context=$context -o json | jq '.spec.containers[] | select(.name == "mgmt") | .env | to_entries[] | select(.value != null and .value.name == "VAION_USER_DATA") | .value.value')
	if [[ $? -ne 0 ]]; then
		logFile=/tmp/vms_action_failure_$vms
		kubectl get pod $pod -n $namespace --context=$context -o json > $logFile
		echo "Unknown version - check $logFile"
		exit 0
	fi
	# kubectl returns a weirdly quoted json string, so we can't just use jq on the output. We must grep for the version pattern.
	echo $userData | sed -e 's/.*\\"version\\":\\"\(._._[^"]*\)\\".*/\1/'
}

__getVmsURL() {
	kubectl get ingress ${pod/-0/} --context=$context --namespace=$namespace -o wide | tail -n 1 | cut -d' ' -f 7
}

case $whatToDo in
	db)
		__fillVmsKubeConfig db
		set -x
		kubectl -n $namespace exec -it $pod --context=$context --container db -- psql -U postgres -d vaionmgmt
		;;

	log)
		arg=
		if [[ $component = db ]]; then
			arg=db
		fi
		__fillVmsKubeConfig $arg
		f=
		if [[ $follow = true ]]; then
			f="-f"
		fi
		cmd="kubectl logs --context=$context --namespace=$namespace $pod $f --tail=$tail $component $@"

		if [[ -z $mapFile ]]; then
			mapFile=$vms
		fi
		if [[ $mapFile != none ]]; then
			cmd+=" | map-IDs.sh $vms"
		fi
		if [[ $follow = false ]]; then
			cmd+=" | less -rS"
		fi

		echocolour $cmd
		eval $cmd
		;;

	patch)
		set -x
		$VAION_PATH/go/cloud/scripts/patch-vms $vms $component ${namespace/clouddemo_vcloud_/} --context=$context $@
		;;

	curl)
		__fillVmsKubeConfig
		url=$(__getVmsURL $vms)
		d=
		[[ $debug = true ]] && d=--debug
			
		cookie=$(get-cookie $url $d)

		if [[ $curlPrint != -v && $curlMethod = GET ]]; then
			curlPrint=''
		fi

		cmd="curl --cookie va=$cookie https://$url/api/v1/$curlTail $curlPrint -X $curlMethod"
		printCmd="curl --cookie va=... https://$url/api/v1/$curlTail $curlPrint -X $curlMethod"
		if [[ ! -z $curlData ]]; then
			cmd+=" -d '$curlData'"
			printCmd+=" -d '$curlData'"
		fi

		echocolour "$printCmd" >&2
		echo "Curl logs in /tmp/vms-action-curl.log" >&2
		eval $cmd 2>/tmp/vms-action-curl.log
		;;
	version)
		__getVersion
		;;

	checkout)
		if ! diff --brief . $VAION_PATH; then
			echo "You must be in $VAION_PATH for this" >&2
			exit 0
		fi
		git checkout $(__getVersion)
		;;

	*)
		echo "Unrecognised operation $whatToDo"
		printHelp
		exit 1
		;;
esac