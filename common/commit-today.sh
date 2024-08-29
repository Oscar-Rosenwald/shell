#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

date=$(date "+%d.%m. %Y")
git diff
git commit -a -m "$date"
git push