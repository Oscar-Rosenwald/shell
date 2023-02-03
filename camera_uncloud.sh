#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

function show_help {
cat<<EOF
$0 [-h] [-c|--cloud] [-ip <camera IP>] [-m <model>] [-p <password>]
Convert a camera to cloud/onprem.
WARNING - DOES NOT WORK

-h,  --help        Show help.
-ip                Camera IP
-c,  --cloud       Convert to cloud. Defaults to on-prem.
-m                 Specify new model. Defaults to COMPACTDOME-W if converting to on-prem, and COMPACTDOME-W-5MP-30 if to cloud.
-p,  --password    Specify SSH password. (Requres sshpass)
     --force-ssh   Don't use sshpass even if you have it installed. Ignores the -p option. Default is true.
EOF
}

CAMERA=10.10.2.110 # My compact dome camera
CLOUD="false"
PASSWORD=archivepartoftheoffice
forceSSH=false

# Handle options
while [[ "$#" -gt 0 ]]; do
	opt="$1"
	shift
	case "$opt" in
		-h|--help)
			show_help
			exit 0
			;;
		-ip)
			CAMERA="$1"
			shift
			;;
		-c|--cloud)
			CLOUD=true
			;;
		-m)
			MODEL="$1"
			shift
			;;
		-p|--password)
			PASSWORD="$1"
			shift
			;;
		--force-ssh)
			forceSSH=true
			;;
		*)
			show_help
			exit 1
	esac
done

# Handle model
if [[ -z "${MODEL:-}" ]]; then
	if [[ $CLOUD = true ]]; then
		MODEL=COMPACTDOME-W-5MP-30
	else
		MODEL=COMPACTDOME-W
	fi
fi

FDISK_COMMANDS="d\nn\np\n1\n\n200000000\nn\np\n2\n\n\nt 1\nb\nw\n"

echo "Setting camera $CAMERA as "$(if [[ "$CLOUD" = true ]]; then echo "cloud"; else echo "on-prem"; fi)", with model $MODEL."

# command=<<EOF
		# export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin;

		# systemctl stop camera;

		# sed -i 's/"model":"[^"]*"/"model":"$MODEL"/g' /mnt/persistent/settings/factory/provision.json;
		# sed -ie 's/"is_cloud_camera":\(true\|false\)/"is_cloud_camera":"$CLOUD"/g' /mnt/persistent/settings/factory/provision.json;

		# systemctl start camera;

		# exit
# EOF
command=<<EOF
ls
exit
EOF

# Check if we can use ssh password without prompting
if [[ ! -z $(dpkg -s sshpass 2>/dev/null) ]] && [[ "$forceSSH" = false ]]; then
	sshpass -p $PASSWORD ssh admin@${CAMERA} /bin/bash < <(eval $command)
else
	ssh admin@${CAMERA} /bin/bash 
fi
echo "deleting known host"

# Doing the above to the camera resets the host key. This means if you had SSHed into it before, the next SSH would require
# you to run the following. I took the liberty of doing so myself.
# ssh-keygen -f ~/.ssh/known_hosts -R "$CAMERA"