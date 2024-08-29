#!/usr/bin/env bash

pic=/tmp/screen.png
rm $pic
flameshot full --path $pic 1>&2 2>/tmp/freeze-lock-screen.log
i3lock -i $pic -u
setxkbmap us