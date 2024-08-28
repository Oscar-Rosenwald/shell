#!/bin/bash

function makeNew() {
	image=$1
	imageName=${image%.png}
	newSuffix=$2

	origWidth=$3
	origHeight=$4

	newWidth=$5
	newHeight=$6

	if [[ $origHeight -gt $newHeight ]]; then
		cmd="magick $image -resize x${newHeight} $imageName-resized.png"
		echo $cmd
		eval $cmd
		image=$imageName-resized.png
	fi


	radius=$((newWidth/2+200))
	cmd="magick composite -gravity center $image \( -size ${newWidth}x${newHeight} -define gradient:radii=${radius},${radius} radial-gradient:black-#3C0949 \) ${imageName}_${newSuffix}.png"
	echo $cmd
	eval $cmd
}

for file in ./*.png; do
	width=$(magick identify -format "%[fx:w]" $file)
	height=$(magick identify -format "%[fx:h]" $file)

	makeNew $file Uxbridge $width $height 3440 1440 
	makeNew $file Base $width $height 1920 1080 
	makeNew $file Home $width $height 3840 2160 
	makeNew $file Victoria $width $height 3840 1200 
done

# These files are temporary to help us with images that are too big for the screens.
rm *-resized.png