#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

printHelp() {
cat <<EOF
$0 <vms-name> [ <component> [-t num] [-l] | -db | --patch <component> | --curl <URL tail> [delete | put/create '<data>'] [-v] [-p] | --version ] [-c <context>] [-n <namespace>] [--no-map]

Perform commmon VMS actions.

component            Log from this component and follow the log. Default is mgmt.
-t                   Log this many lines. Default is 500.
-l                   Don't follow the log, but display it in 'less' fashion.

-db                  Log into the database of the VMS.

--patch <component>  Patch this component. Default is mgmt.

--curl <URL tail>... Run a curl command against the VMS. <URL tail> is what follows "/api/v1/". GET is default. PUT and CREATE require data WITHOUT BRACKETS!
-v                   Run verbose. If not given, we run -i (which prints the response code).
-p                   Print the curl command. Note that you cannot pipe such an output to jq.

-c <context>         Use this context. Default is aw1.
-n <namespace>       Use this namespace. Default is prod. Leave out clouddemo-vcloud-.

--version            Returns the VMS version.

--debug              Turn on debugging.

By default, we try to map the output's IDs onto real names. use --no-map to disable this.
EOF
}

namespace=clouddemo-vcloud-prod
context=
whatToDo=log
vms=
follow=true
tail=100
debug=false
mapFile=

allowedCurlMethod=("put" "create" "get" "delete")
curlData=
curlMethod=
curlTail=
curlPrint='-w "cURL response: %{http_code}\n"'
curlVerbose=false

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
		--version)
			whatToDo=version
			;;
		--no-map)
			mapFile=none
			;;
		--patch)
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
		-v)
			curlPrint=-v
			;;
		-p)
			curlVerbose=true
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
				elif [[ $curlMethod = put || $curlMethod = create ]]; then
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

# Get the cached context if we have one.
if [[ -z $context ]]; then
	cachedFile=$MAPS/$vms
	context=aw1 # Default
	
	if [[ -f $cachedFile ]] && grep -q "^Context:" $cachedFile; then
		context=$(grep "^Context:" $cachedFile | cut -d ':' -f 2)
	else
		context=$(cloudvmsctl find $vms | jq '.[].Cluster' | sed 's/\"//g')
		if [[ -f $cachedFile ]]; then
			echo "Context:$context" >> $cachedFile
		fi
	fi
fi

__getPodName() {
	g="-v"
	[[ ${1:-} = db ]] && g=''

	depInternalName=$(kubectl --context=$context --namespace=$namespace get ingress | grep "$vms\." | cut -d ' ' -f 1)
	echo $(kubectl --context=$context --namespace=$namespace get pods | grep $depInternalName | grep $g '\-db-' | head -n 1 | cut -d ' ' -f 1)
}

__getVmsURL() {
	kubectl get ingress $vms --context=$context --namespace=$namespace | tail -n 1 | cut -d' ' -f 7
}

case $whatToDo in
	db)
		pod=$(__getPodName db)
		set -x
		kubectl -n $namespace exec -it $pod --context=$context --container db -- psql -U postgres -d vaionmgmt
		;;
	log)
		pod=$(__getPodName)
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
		url=$(__getVmsURL $vms)
		cookie=$(get-cookie $url)

		if [[ $curlPrint != -v && $curlMethod = GET ]]; then
			curlPrint=''
		fi

		cmd="curl --cookie va=$cookie https://$url/api/v1/$curlTail $curlPrint -X $curlMethod"
		printCmd="curl --cookie va=... https://$url/api/v1/$curlTail $curlPrint -X $curlMethod"
		if [[ ! -z $curlData ]]; then
			cmd+=" -d '$curlData'"
			printCmd+=" -d '$curlData'"
		fi

		if [[ $curlVerbose = true ]]; then
			echocolour "$printCmd"
		fi

		eval $cmd
		;;
	version)
		pod=$(__getPodName)
		userData=$(kubectl get pod $pod -n $namespace --context=$context -o json | jq '.spec.containers[] | select(.name == "mgmt") | .env | to_entries[] | select(.value != null and .value.name == "VAION_USER_DATA") | .value.value')
		# kubectl returns a weirdly quoted json string, so we can't just use jq on the output. We must grep for the version pattern.
		echo $userData | sed -e 's/.*\\"version\\":\\"\(._._[^"]*\)\\".*/\1/'
		;;
	*)
		echo "Unrecognised operation $whatToDo"
		printHelp
		exit 1
		;;
esac
		