#!/usr/bin/env bash


function ggo {
	gg "$@" o
}
export -f ggo

# Prints a digit as a word. If more digits are passed, or if arg 1 isn't a
# digit, prints arg 1.
function __printNumberWord {
	case $1 in
		0) echo zero	;;
		1) echo one		;;
		2) echo two		;;
		3) echo three	;;
		4) echo four	;;
		5) echo five	;;
		6) echo six		;;
		7) echo seven	;;
		8) echo eight	;;
		9) echo nine	;;
		*) echo $1		;;
	esac
}
export -f __printNumberWord

# Inverse of __printNumberWord.
function __printWordNumber {
	case $1 in
		zero)	echo 0	;;
		one)	echo 1	;;
		two)	echo 2	;;
		three)	echo 3	;;
		four)	echo 4	;;
		five)	echo 5	;;
		six)	echo 6	;;
		seven)	echo 7	;;
		eight)	echo 8	;;
		nine)	echo 9	;;
		*)		echo $1 ;;
	esac
}
export -f __printWordNumber
