#!/bin/bash

# gallery.sh
# Author: Nils Knieling - https://github.com/Cyclenerd/gallery_shell
# Inspired by: Shapor Naghibzadeh - https://github.com/shapor/bashgal

#########################################################################################
#### Configuration Section
#########################################################################################

height_small=200
height_large=768
quality=85
thumbdir="__thumbs"
htmlfile="index.html"
title="Gallery"
footer='Created with <a href="https://github.com/Cyclenerd/gallery_shell">gallery.sh</a>'

# playicon is a transparent png which will be overlaid on images from movies
playicon="/your/path/to/playbutton.png"

# Use convert from ImageMagick
convert="convert" 
# Use composite from ImageMagick
composite="composite" 
# Use JHead for EXIF Information on other *nix
# exif="jhead"
# Use exiv2 for EXIF Information under Cygwin
exif="exiv2"
# Use ffmpeg for video thumbnails
ffmpeg="ffmpeg"
# Use ffprobe for video metadata
ffprobe="ffprobe"

# Bootstrap (currently v3.3.7)
# Latest compiled and minified CSS
stylesheet="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css"

downloadicon='<span class="glyphicon glyphicon-floppy-save" aria-hidden="true"></span>'
movieicon='<span class="glyphicon glyphicon-film" aria-hidden="true"></span>'
homeicon='<span class="glyphicon glyphicon-home" aria-hidden="true"></span>'

# Debugging output
# true=enable, false=disable 
debug=true

#########################################################################################
#### End Configuration Section
#########################################################################################


me=$(basename "$0")
datetime=$(date -u "+%Y-%m-%d %H:%M:%S")
datetime+=" UTC"

function usage {
	returnCode="$1"
	echo -e "Usage: $me [-t <title>] [-d <thumbdir>] [-h]:
	[-t <title>]\t sets the title (default: $title)
	[-d <thumbdir>]\t sets the thumbdir (default: $thumbdir)
	[-h]\t\t displays help (this message)"
	exit "$returnCode"
}

function debugOutput(){
	if [[ "$debug" == true ]]; then
		echo "$1" # if debug variable is true, echo whatever's passed to the function
	fi
}

function getFileSize(){
	# Be aware that BSD stat doesn't support --version and -c
	if stat --version &>/dev/null; then
		# GNU
		myfilesize=$(stat -c %s "$1" | awk '{$1/=1000000;printf "%.2fMB\n",$1}')
	else
		# BSD
		myfilesize=$(stat -f %z "$1" | awk '{$1/=1000000;printf "%.2fMB\n",$1}')
	fi
	echo "$myfilesize"
}

while getopts ":t:d:h" opt; do
	case $opt in
	t)
		title="$OPTARG"
		;;
	d)
		thumbdir="$OPTARG"
		;;
	h)
		usage 0
		;;
	*)
		echo "Invalid option: -$OPTARG"
		usage 1
		;;
	esac
done

debugOutput "- $me : $datetime"

### Check Commands
command -v $convert >/dev/null 2>&1 || { echo >&2 "!!! $convert is not installed.  Aborting."; exit 1; }
command -v $composite >/dev/null 2>&1 || { echo >&2 "!!! $composite is not installed.  Aborting."; exit 1; }
command -v $exif >/dev/null 2>&1 || { echo >&2 "!!! $exif is not installed.  Aborting."; exit 1; }
command -v $ffmpeg >/dev/null 2>&1 || { echo >&2 "!!! $ffmpeg is not installed.  Aborting."; exit 1; }
command -v $ffprobe >/dev/null 2>&1 || { echo >&2 "!!! $ffprobe is not installed.  Aborting."; exit 1; }

### Create Folders
[[ -d "$thumbdir" ]] || mkdir "$thumbdir" || exit 2

heights[0]=$height_small
heights[1]=$height_large
for res in ${heights[*]}; do
	[[ -d "$thumbdir/$res" ]] || mkdir -p "$thumbdir/$res" || exit 3
done

### Create Startpage
debugOutput "$htmlfile"
cat > "$htmlfile" << EOF
<!DOCTYPE HTML>
<html lang="en">
<head>
	<meta charset="utf-8">
	<title>$title</title>
	<meta name="viewport" content="width=device-width">
	<meta name="robots" content="noindex, nofollow">
	<link rel="stylesheet" href="$stylesheet">
</head>
<body>
<div class="container">
	<div class="row">
		<div class="col-xs-12">
			<div class="page-header"><h1>$title</h1></div>
		</div>
	</div>
EOF

###########
### Cleanup - convert all filenames to dates for sorting, all extensions to lowercase, all videos to mp4
###########

### Change photo filenames to reflect date and time, and ensure all lowercase
# First remove spaces
for nospace in ./*\ *.[jJ][pP][gG]; do
    mv "$nospace" "${nospace// /}"
done
# Then set filename to date with lowercase jpg
for filerename in *.[jJ][pP][gG]; do
	$exif -q -r '%Y%m%d%H%M%S' rename "${filerename/.[jJ][pP][gG]}".jpg
done

### Change video filenames to reflect date and time - temporarily rename mp4 to m4v
for videorename in *.[mM][pP]4*; do
	ff=$($ffprobe -v quiet "$videorename" -show_entries format_tags=creation_time  2>&1 | grep creation_time | sed 's/[^0-9]*//g')
	mv "$videorename" "$ff.m4v"
done
for videorename in *.[mM][oO][vV]*; do
	ff=$($ffprobe -v quiet "$videorename" -show_entries format_tags=creation_time  2>&1 | grep creation_time | sed 's/[^0-9]*//g')
	mv "$videorename" "$ff.mov"
done
# Convert mov to mp4
for convertmov in `ls *.mov | awk -F . '{print $1}'`; do
	$ffmpeg -i "$convertmov.mov" -vcodec libx264 -s 720x404 -aspect 16:9 -b:v 2000k -b:a 128k -ar 44100 "$convertmov.mp4"
    	# Extract jpg from 2 second point of movie    
    	$ffmpeg -itsoffset -2 -i "$convertmov.mov" -vcodec mjpeg -vframes 1 -an -f rawvideo -s 365x205 $convertmov-video.jpg
        	# Add a play icon to the image
    		$composite -gravity center $playicon $convertmov-video.jpg $convertmov-video.jpg
done
# Re-encode mp4 (m4v) to reduce size
for reducemp4 in `ls *.m4v | awk -F . '{print $1}'`; do
	# Re-encode
	$ffmpeg -i "$reducemp4.m4v" -vcodec libx264 -s 720x404 -aspect 16:9 -b:v 2000k -b:a 128k -ar 44100 "$reducemp4.mp4"
    	# Extract jpg from 2 second point    
    	$ffmpeg -itsoffset -2 -i "$reducemp4.mp4" -vcodec mjpeg -vframes 1 -an -f rawvideo -s 365x205 $reducemp4-video.jpg
    		# Add a play icon to the image    
    		$composite -gravity center $playicon $reducemp4-video.jpg $reducemp4-video.jpg
done
# Remove original mov and m4v - make sure you have backups!
rm *.mov *.m4v

###############
### End Cleanup
###############

### Photos (JPG)
if [[ $(find . -maxdepth 1 -type f -name \*.jpg | wc -l) -gt 0 ]]; then
	echo '<div class="row">' >> "$htmlfile"

### Generate Images and index links
numfiles=0
for filename in `ls *.[jJ][pP][gG] | awk -F . '{print $1}'`; do
	filelist[$numfiles]=$filename
	let numfiles++
	for res in ${heights[*]}; do
		if [[ ! -s $thumbdir/$res/$filename.jpg ]]; then
			debugOutput "$thumbdir/$res/$filename.jpg"
			$convert -auto-orient -strip -quality $quality -resize x$res "$filename.jpg" "$thumbdir/$res/$filename.jpg"
		fi
	done
cat >> "$htmlfile" << EOF
<div class="col-md-3 col-sm-12">
	<p>
		<a href="$thumbdir/$filename.html"><img src="$thumbdir/$height_small/$filename.jpg" alt="" class="img-responsive"></a>
		<div class="hidden-md hidden-lg"><hr></div>
	</p>
</div>
EOF

[[ $((numfiles % 4)) -eq 0 ]] && echo '<div class="clearfix visible-md visible-lg"></div>' >> "$htmlfile"
done
echo '</div>' >> "$htmlfile"

## Generate the HTML Files for Images in thumbdir
numfiles=0
#for filename in *.[jJ][pP][gG]; do
for filename in `ls *.[jJ][pP][gG] | awk -F . '{print $1}'`; do
	filelist[$numfiles]=$filename
	let numfiles++
done
file=0
while [[ $file -lt $numfiles ]]; do
	filename=${filelist[$file]}
	prev=""
	next=""
	[[ $file -ne 0 ]] && prev=${filelist[$((file - 1))]}
	[[ $file -ne $((numfiles - 1)) ]] && next=${filelist[$((file + 1))]}
	imagehtmlfile="$thumbdir/$filename.html"
	exifinfo=$($ffprobe "$filename.jpg")
	filesize=$(getFileSize "$filename.jpg")
	filesizemovie=$(getFileSize "${filename%??????}.mp4")
	debugOutput "$imagehtmlfile"
	cat > "$imagehtmlfile" << EOF
<!DOCTYPE HTML>
<html lang="en">
<head>
<meta charset="utf-8">
<title>$filename</title>
<meta name="viewport" content="width=device-width">
<meta name="robots" content="noindex, nofollow">
<link rel="stylesheet" href="$stylesheet">
</head>
<body>
<div class="container">
<div class="row">
	<div class="col-xs-12">
		<div class="page-header"><h2><a href="../$htmlfile">$homeicon</a> <span class="text-muted">/</span> $filename</h2></div>
	</div>
</div>
EOF

	# Pager
	echo '<div class="row"><div class="col-xs-12"><nav><ul class="pager">' >> "$imagehtmlfile"
	[[ $prev ]] && echo '<li class="previous"><a href="'"$prev"'.html"><span aria-hidden="true">&larr;</span></a></li>' >> "$imagehtmlfile"
	[[ $next ]] && echo '<li class="next"><a href="'"$next"'.html"><span aria-hidden="true">&rarr;</span></a></li>' >> "$imagehtmlfile"
	echo '</ul></nav></div></div>' >> "$imagehtmlfile"

	cat >> "$imagehtmlfile" << EOF
<div class="row">
	<div class="col-xs-12">
EOF
		if [[ "$filename" == *-video ]]; then
		echo '<p>"<video src=../'"${filename%??????}"'.mp4 controls preload></video>" </p>'  >> "$imagehtmlfile"
		else
		echo '<p><img src="'"$height_large"'/'"$filename"'.jpg" class="img-responsive" alt=""></p>' >> "$imagehtmlfile"
		fi
		cat >> "$imagehtmlfile" << EOF
		</div>
</div>
<div class="row">
	<div class="col-xs-12">
EOF
		if [[ "$filename" == *-video ]]; then
		echo '<p><a class="btn btn-info btn-lg" href="../'"${filename%??????}"'.mp4">'"$downloadicon"' Download Original ('"$filesizemovie"')</a></p>' >> "$imagehtmlfile"
		else
		echo '<p><a class="btn btn-info btn-lg" href="../'"$filename"'.jpg">'"$downloadicon"' Download Original ('"$filesize"')</a></p>' >> "$imagehtmlfile"
		fi
cat >> "$imagehtmlfile" << EOF
	</div>
</div>
EOF

	# EXIF
	if [[ $exifinfo ]]; then
		cat >> "$imagehtmlfile" << EOF
<div class="row">
<div class="col-xs-12">
<pre>
$exifinfo
</pre>
</div>
</div>
EOF
	fi

	# Footer
	cat >> "$imagehtmlfile" << EOF
</div>
</body>
</html>
EOF
	let file++
done

fi

### Footer
cat >> "$htmlfile" << EOF
<hr>
<footer>
	<p>$footer</p>
	<p class="text-muted">$datetime</p>
</footer>
</div> <!-- // container -->
</body>
</html>
EOF

debugOutput "= done :-)"
