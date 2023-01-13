#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

file=$1
component="${2:-mgmt}" 			# TODO Make this aware of lib/ directory in dynamic computation of the file's place
includeTime=false
if [[ "${3:-}" != "" ]]; then
	includeTime=true
fi

sed -i -n '/___/p' $file 		# Only indluce lines matching ___
sed -i 's/^\([^\t]\+\t\)\t*[^\t]\+\t\+/\1/' $file # Get rid of the INFOs and WARNs
if [[ $includeTime = false ]]; then
	sed -i 's/^[^\t]\+[\t ]*//' $file # Get rid of timestamp unless user wants it
fi									  # TODO Doesn't work when keeping timestamps!!!!!!!!
sed -i 's/[^\t]\+\t\+\([^\t]\+\)\t\+___/\1\t___/' $file # Get rid of arbitrary logger names
sed -i 's/ (0x.*)//g' $file		# Get rid off "useless" pointer spam filter resistor
sed -i "s;\([^ \t]\+.go:.\+\);$component/\1;" $file	# Add component's name at beginning of lines.
