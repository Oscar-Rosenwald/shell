#!/usr/bin/env bash

set -xeuo pipefail
IFS=$'\n\t'

if [[ "$#" -ne 1 ]]; then
    echo "Usage $0 <component>"
    exit 1
fi

comp="$1"

function compress() {
	pigz -k -p8 < "$1" > "$2"
}

case "$comp" in
	ana|cuda_ana)
		echo "Use ./scripts/update_ana.sh to update ana instead"
		exit 1
		;;
	simple_ana)
		comp="ana"
		image_tag="bazel/go/vms/ana/simple_ana:simple_ana_image"
		image_file="/tmp/ana_image.tgz"
		make -C $VAION_PATH build_vms_simple_ana_image
		compress "bazel-bin/go/vms/ana/simple_ana/simple_ana_image.tar" "$image_file"
		;;
	ui)
		image_tag="bazel/ui:ui_image"
		image_file="/tmp/ui_image.tgz"
		make -C $VAION_PATH vmsui_prep
		make -C $VAION_PATH vmsui_build
		compress "bazel-bin/ui/ui_image.tar" "$image_file"
		;;
	ui-quick)
		# development only build, skips dependency install and minification
		comp="ui"
		image_tag="bazel/ui:ui_image"
		image_file="/tmp/ui_image.tgz"
		make -C $VAION_PATH vmsui_build_quick
		compress "bazel-bin/ui/ui_image.tar" "$image_file"
		;;
	*)
		make -C $VAION_PATH build_vms_bazel_image COMPONENTS="$comp"
		image_tag="bazel/go/vms/$comp:${comp}_image"
		image_file="/tmp/${comp}_image.tgz"
		compress "bazel-bin/go/vms/$comp/${comp}_image/tarball.tar" "$image_file"
		;;
esac
