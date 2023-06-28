#!/bin/bash

set -eou pipefail

function showHelp() {
	cat <<EOF
$0 [--raw] [-o <output-file>] [-d <subdirectory>]

Write all text from chapters in the current diretory (recursively) into a single file, keeping track of sections and subsections.

--raw   Only accumulate the text; no change
-o      Use this name rather than the name of the current directory
-d      Export only files in <directory>, which will be treated as the "home" directory.

Default is without --raw, which prepares the file for export, but is inadvisable for work.
EOF
	exit 0
}

dir=$(pwd)
outputFile=
raw=

# Parse arguments
while [[ "$#" -gt 0 ]]; do
	opt="$1"
	shift

	case "$opt" in
		--raw)
			raw=raw
			;;
		-o)
			outputFile="$1"
			shift
			;;
		-d)
			dir="$1"
			shift
			;;
		-h)
			showHelp
			exit 0
			;;
		*)
			echo "Unknown option $opt"
			showHelp
			exit 1
			;;
	esac
done

if [[ -z "$outputFile" ]]; then
	fileName=`basename "$dir"`
else
	fileName="$outputFile"
fi
tmpFile="$(pwd)"/tmpFile
fullFileName="$(pwd)"/"$fileName".org
cat > "$tmpFile" <<EOF
# -*- eval: (linum-mode -1); -*-
#+TITLE: $fileName
#+OPTIONS: author:nil timestamp:nil num:nil toc:nil

EOF

cd "$dir"

echo "Writing to file $tmpFile"

function writeFile() {
	fullFile="$1"
	fileNoExtension="${1%.*}"
	sectionDepth="$2" # Stars

	echo "*$sectionDepth $fileNoExtension" | sed -E 's/[0-9]+ - //' >> "$tmpFile"
	cat "$fullFile" >> "$tmpFile"
	echo >> "$tmpFile"
}

function importSection() {
	section="$1"
	sectionDepth="$2"

	echo "Importing section $section at depth $sectionDepth"
	cd "$section"

	echo "$sectionDepth $section" | sed -E 's/[0-9]+ - //' >> "$tmpFile"
	ls -1v | while read fileOrSection; do
		if [[ -d "$fileOrSection" ]]; then
			importSection "$fileOrSection" "*$sectionDepth"
		elif [[ ! "$fileOrSection" = "$fileName" ]]; then
			writeFile "$fileOrSection" "$sectionDepth"
		fi
	done

	cd ..
}

# Import raw text to one file
gls -v1 | grep "^[0-9]\+ - .*" | while read section; do
	if [[ -f "$section" ]]; then
		writeFile "$section" ""
	else 
		importSection "$section" "*"
	fi
done

if [[ ! -z $raw ]]; then
	mv "$tmpFile" "$fullFileName"
	echo "Exported raw text only to $fullFileName"
	exit 0
fi

# Scene breaks
echo "Handling scene transitions"
sceneBreakStart="#+BEGIN_CENTER"
sceneBreakMiddle="*"
sceneBreakEnd="#+END_CENTER"
sed -i'' -e "s/^==$/$sceneBreakStart\n$sceneBreakMiddle\n$sceneBreakEnd/" "$tmpFile"
rm "$tmpFile"-e # sed creates a backup with '-e' at the end.

# Special blocks
echo 'Handling "quoted" sections'

firstLine=false   # Current line is the first line after a heading
insideBlock=false # Current line is inside a block

justEnteredBlock=false
justExitedBlock=false

blockStart=#+begin_quote
blockEnd=#+end_quote

if [[ -f "$fullFileName" ]]; then
	echo "Removing file $fullFileName to recreate it"
	rm "$fullFileName"
fi

while read line; do
	if [[ "$line" =~ ^\*+\ .*$ ]]; then
		firstLine=true
		justEnteredBlock=false
		justExitedBlock=false
		echo "$line" >> "$fullFileName"

	else
		if [[ $justExitedBlock = true ]]; then
			# Remove second to last line
			lines=`wc -l < "$fullFileName"`
			lineNum=$((lines - 1))
			awk "NR != $lineNum{print}" "$fullFileName" > _backup
			mv _backup "$fullFileName"

			# Add scene break after block
			echo >> "$fullFileName"
			echo "$sceneBreakStart" >> "$fullFileName"
			echo "$sceneBreakMiddle" >> "$fullFileName"
			echo "$sceneBreakEnd" >> "$fullFileName"
		elif [[ $justEnteredBlock = true ]] && [[ "$line" =~ ^$ ]]; then
			# Empty line after entering block should not be there.
			justEnteredBlock=false
			continue
		fi

		justExitedBlock=false

		if [[ "$line" =~ ^\+\+$ ]]; then

			if [[ $insideBlock = true ]]; then
				# Block end
				echo "$blockEnd" >> "$fullFileName"
				# TODO Another scene break,
				# unless next one is a heading or end of file
				insideBlock=false
				justExitedBlock=true
			else 
				if [[ $firstLine = false ]]; then
					echo >> "$fullFileName"
					echo "$sceneBreakStart" >> "$fullFileName"
					echo "$sceneBreakMiddle" >> "$fullFileName"
					echo "$sceneBreakEnd" >> "$fullFileName"
				fi

				# Block start
				echo "$blockStart" >> "$fullFileName"
				insideBlock=true
				justEnteredBlock=true
			fi
			firstLine=false

		else # Normal line
			echo "$line" >> "$fullFileName"
			firstLine=false
		fi
	fi
done < "$tmpFile"

echo "Removing temp file"
rm "$tmpFile"