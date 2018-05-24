#!/bin/bash
echo "Home page: https://github.com/james-hu/mmingest"

command -v exiftool >/dev/null 2>&1 || { echo >&2 "exiftool is not installed.  Aborting."; exit 1; }
command -v exiftran >/dev/null 2>&1 || { echo >&2 "exiftran (part of fbida) is not installed.  Aborting."; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg with libfdk is not installed.  Aborting."; exit 1; }
ffmpeg -h 2>&1 | grep -q enable-libfdk-aac || { echo >&2 "ffmpeg does not have libfdk enabled.  Aborting."; exit 1; }

ORIGINAL_INPUT_PATH="$1"
OUTPUT_PATH="$2"

if [ -z "$ORIGINAL_INPUT_PATH" ]; then
	echo >&2 "Please specify source directory as the first argument. Files in the source directory will not be modified."
	exit 1
fi

if [ -z "$OUTPUT_PATH" ]; then
	echo >&2 "Please specify destination directory as the second argument. If the directory does not exist, it will be created."
	exit 1
fi

mkdir -p "$OUTPUT_PATH"
INPUT_PATH="${OUTPUT_PATH}/copy"
LOG_FILE="$OUTPUT_PATH/ingest.log"

log(){
	action="$1"
	f1="$2"
	f2="$3"
	ratio="$4"
	if [ -z "$ratio" ]; then
		f1size=$(wc -c < "$f1")
		f2size=$(wc -c < "$f2")
		ratio=$(echo "scale=2;100*$f2size/$f1size" | bc)
	fi
	echo "$action: ($ratio%) $f1 -> $f2" >> "$LOG_FILE"
}

move_related_files(){
	inf="$1"
	outf="$2"
	for suffix in ".xmp", ".XMP", ".aae", ".AAE"; do
		if [[ -s "${inf%.*}$suffix" ]]; then
			mv "${inf%.*}$suffix" "${outf%.*}$suffix"
		fi
	done
}

echo `date` >> $LOG_FILE

trap "exit" INT

echo "###### Making a copy of the input directory to work on"
cp -R -p -f "$ORIGINAL_INPUT_PATH" "$INPUT_PATH"

echo "###### Processing photos found in: $INPUT_PATH"
find "$INPUT_PATH" -type f \( -iname '*.jpg' -o -iname '*.cr2' -o -iname '*.png' \) -print0 | while read -d $'\0' infile
do
	infile_size=$(wc -c < "$infile")
	if (( infile_size < 2 )); then
		log "skipped" "$infile" "" "--"
		continue
	fi

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
		log "rotated" "$infile" "$outfile"
	else
		log "copied" "$infile" "$outfile" "100.00"
	fi

	rm -f "$infile"
	move_related_files "$infile" "$outfile"
done

echo "###### Processing videos found in: $INPUT_PATH"
find "$INPUT_PATH" -type f \( -iname '*.mp4' -o -iname '*.3gp' -o -iname '*.mp4' -o -iname '*.mov' -o -iname '*.avi' \) -print0 | while read -d $'\0' infile
do
	infile_size=$(wc -c < "$infile")
	if (( infile_size < 2 )); then
		log "skipped" "$infile" "" "--"
		continue
	fi

	filename=`basename "$infile"`
	filename_no_suffix="${filename%.*}"
	filesuffix="${filename##*.}"
	new_name_no_suffix=`exiftool -MediaCreateDate -S -d "%Y/%Y-%m/%Y%m%d_$filename_no_suffix" "$infile" |cut -c 18-`
	if [ -z "$new_name_no_suffix" ]; then
		new_name_no_suffix=`exiftool -FileModifyDate -S -d "%Y/%Y-%m/%Y%m%d_$filename_no_suffix" "$infile" |cut -c 17-`
	fi

	#mvfile="$OUTPUT_PATH/videos/original/$new_name_no_suffix.$filesuffix"
	#mvdir="${mvfile%/*}"
	#outfile="$OUTPUT_PATH/videos/converted/$new_name_no_suffix.mp4"
	outfile="$OUTPUT_PATH/videos/$new_name_no_suffix.mp4"
	outdir="${outfile%/*}"
	#mkdir -p "$mvdir"
	mkdir -p "$outdir"

	#echo "$infile -> $mvfile -> $outfile"
	#cp -p "$infile" "$mvfile"
	echo "$infile -> $outfile"

	ffprobe "$infile" 2>&1 | grep -q "Video: h264"
	if [ $? -eq 0 ]; then
		# try re-package first
		ffmpeg -hide_banner -nostats -loglevel panic -y -i "$infile" -vcodec copy -acodec copy -movflags faststart -map_metadata 0 -f mp4 "$outfile" &
		wait $!
		repackage_ratio=$(echo "scale=0;100*$infile_size/$(wc -c < "$outfile")" | bc)
	else
		repackage_ratio="9999"
	fi
	# echo "infile_size=$infile_size"
	# echo "repackage_ratio=$repackage_ratio"

	if (( $repackage_ratio > 80 )); then
		# try transcoding as well
		ffmpeg -hide_banner -nostats -loglevel panic -y -i "$infile" -c:v libx264 -crf 21 -profile:v main -level 4.1 -preset veryslow -g 150 -pix_fmt yuvj420p -c:a libfdk_aac -profile:a aac_he -b:a 64k -ar 32000 -movflags faststart -map_metadata 0 -f mp4 "$outfile.transcoded.mp4" &
		wait $!
		transcode_ratio=$(echo "scale=0;100*$infile_size/$(wc -c < "$outfile.transcoded.mp4")" | bc)
		# echo "transcode_ratio=$transcode_ratio"
		if (( $repackage_ratio > $transcode_ratio + 15 )); then
			# use transcoded
			rm -f "$outfile"
			mv "$outfile.transcoded.mp4" "$outfile"
			log "transcoded" "$infile" "$outfile" $transcode_ratio
		else
			# use repackaged
			rm -f "$outfile.transcoded.mp4"
			log "re-packaged" "$infile" "$outfile" $repackage_ratio
		fi
	else
		log "re-packaged" "$infile" "$outfile" $repackage_ratio
	fi

	rm -f "$infile"
	move_related_files "$infile" "$outfile"
done

# repeat several times to remove empty directories
for i in {1..10}
do
   find "$OUTPUT_PATH" -empty -type d -delete
done

command -v dot_clean >/dev/null 2>&1
if [ $? -eq 0 ]; then
	dot_clean -m "$OUTPUT_PATH"
fi
find "$OUTPUT_PATH" -name "._*" -delete
find "$OUTPUT_PATH" -name ".DS_Store" -delete
