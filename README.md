# mmingest

This is the tool to move and transform your photos and videos. It is handy for importing and organizing photos and videos taken by phones, tablets, and cameras.

## Third party tools required
* bash
* exiftool
 * On Mac, install with ```brew install exiftool```
* exiftran
 * On Mac, install with ```brew install fbida```
* ffmpeg with FDK codec
 * On Mac, install with ```brew install ffmpeg --with-fdk-aac```

## Usage

Just run ```ingest.sh```. You must specify the source directory as the first argument and the destination directory as the second argument.

If you forgot to install required third party tools or forgot to specify the arguments, you will be prompted.

The destination directory will be created automatically if it does not exist.

All output go into the destination directory, including the log file and a temporary working directory. For example, if your destination directory is ```/tmp/processed```, then the log file will be ```/tmp/processed/ingest.log```, and the temporary working directory will be ```/tmp/processed/tmp```.

Please make sure that there is enough space in the destination directory.

## Behavior

* Files in the source directory will not be deleted or modified. They will be copied into the working directory before being processed. So it is safe to point the source directory to the location on your phone or camara. And if you want to re-process all the files, you just need to remove the working directory and clean up the destination directory and run the command line again.

* For photo files, they will be moved/renamed into ```photos/YYYY/MM/YYYY_MM_DD/YYYYMMDD_<original_file_name>``` in the destination directory. Image rotation will happen if the EXIF meta data indicates that the photo should be rotated when being displayed.

* For videos, they will be transcoded into "H.264+AAC in web streaming friendly MP4 container" format and saved as ```videos/converted/YYYY/YYYY-MM/YYYYMMDD_<original_file_name>.mp4``` in the destination directory. In the case that the compression ratio of the transcoding is greater than 80%, the original file will be simply re-packaged rather than transcoded.
