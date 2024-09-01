#!/usr/bin/env bash

# TODO This probably doesn't work as well as you think.

set -euo pipefail
IFS=$'\n\t'

date=$(date "+%d.%m. %Y")
git diff
git commit -a -m "$date"
git push