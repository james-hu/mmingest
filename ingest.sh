#!/bin/bash
INPUT_PATH="$1"
OUTPUT_PATH="$2"

#INPUT_PATH=/media/james/Windows/tmp3
#OUTPUT_PATH=./work

if [ -z "$INPUT_PATH" ]; then
	echo "Please specify the source directory as the first argument"
fi

if [ -z "$OUTPUT_PATH" ]; then
	echo "Please specify the destination directory as the second argument"
fi

echo "###### Processing photos found in: $INPUT_PATH"
for infile in `find $INPUT_PATH -type f \( -name '*.jpg' -o -name '*.JPG' \)`
do
	filename=`basename $infile`
	filename_no_suffix=${filename%.*}
	new_name=`exiftool -exif:DateTimeOriginal -S -d "%Y/%m/%Y_%m_%d/%Y%m%d_$filename_no_suffix.jpg" $infile |cut -c 19-`
	if [ -z "$new_name" ]; then
		new_name=`exiftool -FileModifyDate -S -d "%Y/%m/%Y_%m_%d/%Y%m%d_$filename_no_suffix.jpg" $infile |cut -c 17-`
	fi
	outfile=$OUTPUT_PATH/$new_name
	echo "$infile -> $outfile"

	orientation=`exiftool -b -exif:Orientation# -S  $infile`
	if [ "$orientation" != "" ] && [ "$orientation" != "1" ]; then
		exiftrans -aip $outfile
	fi
	
done

echo "###### Processing videos found in: $INPUT_PATH"
for infile in `find $INPUT_PATH -type f \( -name '*.mp4' -o -name '*.MP4' -o -name '*.mov' -o -name '*.MOV' -o -name '*.avi' -o -name '*.AVI' \)`
do
	filename=`basename $infile`
	filename_no_suffix=${filename%.*}
	new_name=`exiftool -MediaCreateDate -S -d "%Y/%Y-%m/%Y%m%d_$filename_no_suffix.mp4" $infile |cut -c 18-`
	if [ -z "$new_name" ]; then
		new_name=`exiftool -FileModifyDate -S -d "%Y/%Y-%m/%Y%m%d_$filename_no_suffix.mp4" $infile |cut -c 17-`
	fi
	outfile=$OUTPUT_PATH/$new_name
	echo "$infile -> $outfile"
	ffmpeg -y -i "$infile" -c:v libx264 -crf 21 -profile:v main -level 4.1 -preset veryslow -g 150 -c:a libfdk_aac -profile:a aac_he -b:a 64k -movflags faststart -map_metadata 0 -f mp4 "$outfile"
done
