#!/bin/bash
ORIGINAL_INPUT_PATH="$1"
OUTPUT_PATH="$2"

if [ -z "$ORIGINAL_INPUT_PATH" ]; then
	echo "Please specify the source directory as the first argument"
	exit
fi

if [ -z "$OUTPUT_PATH" ]; then
	echo "Please specify the destination directory as the second argument"
	exit
fi

mkdir -p "$OUTPUT_PATH"
INPUT_PATH="${ORIGINAL_INPUT_PATH}_work"
LOG_FILE="$OUTPUT_PATH/ingest.log"

log(){
	f1="$1"
	f2="$2"
	f1size=$(wc -c < "$f1")
	f2size=$(wc -c < "$outfile")
	ratio=$(echo "scale=2;100*$f2size/$f1size" | bc)
	echo "$f1, $f2, $ratio%" >> "$LOG_FILE"
	
}

echo `date` >> $LOG_FILE

trap "exit" INT

echo "###### Making a copy of the input directory to work on"
cp -R -f "$ORIGINAL_INPUT_PATH" "$INPUT_PATH"

echo "###### Processing photos found in: $INPUT_PATH"
find "$INPUT_PATH" -type f \( -iname '*.jpg' -o -iname '*.cr2' -o -iname '*.xmp' \) -print0 | while read -d $'\0' infile
do
	
	filename=`basename "$infile"`
	filename_no_suffix="${filename%.*}"
	new_name=`exiftool -exif:DateTimeOriginal -S -d "%Y/%m/%Y_%m_%d/%Y%m%d_$filename" "$infile" |cut -c 19-`
	if [ -z "$new_name" ]; then
		new_name=`exiftool -FileModifyDate -S -d "%Y/%m/%Y_%m_%d/%Y%m%d_$filename" "$infile" |cut -c 17-`
	fi
	orientation=`exiftool -b -exif:Orientation# -S  "$infile"`
	
	outfile="$OUTPUT_PATH/photos/$new_name"
	outdir="${outfile%/*}"
	mkdir -p "$outdir"
	echo "$infile -> $outfile"
	cp -p "$infile" "$outfile"

	if [ "$orientation" != "" ] && [ "$orientation" != "1" ]; then
		exiftran -aip "$outfile"
	fi
	
	log "$infile" "$outfile"
	rm -f "$infile"
done

echo "###### Processing videos found in: $INPUT_PATH"
find "$INPUT_PATH" -type f \( -iname '*.mp4' -o -iname '*.3gp' -o -iname '*.mp4' -o -iname '*.mov' -o -iname '*.avi' \) -print0 | while read -d $'\0' infile
do
	filename=`basename "$infile"`
	filename_no_suffix="${filename%.*}"
	filesuffix="${filename##*.}"
	new_name_no_suffix=`exiftool -MediaCreateDate -S -d "%Y/%Y-%m/%Y%m%d_$filename_no_suffix" "$infile" |cut -c 18-`
	if [ -z "$new_name_no_suffix" ]; then
		new_name_no_suffix=`exiftool -FileModifyDate -S -d "%Y/%Y-%m/%Y%m%d_$filename_no_suffix" "$infile" |cut -c 17-`
	fi
	
	mvfile="$OUTPUT_PATH/videos/original/$new_name_no_suffix.$filesuffix"
	mvdir="${mvfile%/*}"
	outfile="$OUTPUT_PATH/videos/converted/$new_name_no_suffix.mp4"
	outdir="${outfile%/*}"
	mkdir -p "$mvdir"
	mkdir -p "$outdir"
	echo "$infile -> $mvfile -> $outfile"
	cp -p "$infile" "$mvfile"
	
	ffmpeg -hide_banner -nostats -loglevel panic -y -i "$mvfile" -c:v libx264 -crf 21 -profile:v main -level 4.1 -preset veryslow -g 150 -c:a libfdk_aac -profile:a aac_he -b:a 64k -movflags faststart -map_metadata 0 -f mp4 "$outfile" &
	wait $!
	
	log "$infile" "$outfile"
	rm -f "$infile"
done
