# mmingest

This is the tool to move and transform your photos and videos. It is handy for importing and organizing photos and videos taken by phones, tablets, and cameras.

## Dependencies that need to be installed in advance

* bash
  * So that you can run this Shell script.
* exiftool
  * On Mac, install with ```brew install exiftool```
  * On Ubuntu, install with ```sudo apt install exiftool```
* exiftran
  * On Mac, install with ```brew install fbida```
  * On Ubuntu, install with ```sudo apt install exiftran```
* ffmpeg with AAC codec
  * On Mac, install with ```brew tap homebrew-ffmpeg/ffmpeg; brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-fdk-aac```

## Usage

Just run ```ingest.sh [-c] <source-dir> <dest-dir>```. You must specify the source directory as the first (after options) argument and the destination directory as the second argument.

If you forget to install required third party tools or forget to specify the arguments, you will see error messages.

The destination directory will be created automatically if it does not exist.

All write operations happen in the destination directory. Those operations include the creation of a log file and a temporary working directory. For example, if your destination directory is ```/tmp/processed```, then the log file will be ```/tmp/processed/ingest.log```, and the temporary working directory will be ```/tmp/processed/tmp```.

Please make sure that there is enough space in the destination directory.

Options:

- `-c` - Don't try to transcode the original input files 

## Behaviour/Functionality

* Files in the source directory will not be deleted or modified. They will be copied into the working directory before being processed. So it is safe to point the source directory to the location in your phone or camera. And if you want to re-process all the files, you just need to remove the working directory and clean up the destination directory and run the command line again.

* For photo files, they will be moved/renamed into ```photos/YYYY/MM/YYYY_MM_DD/YYYYMMDD_<original_file_name>``` in the destination directory. Image rotation will happen if the EXIF meta data indicates that the photo should be rotated when being displayed.

* For videos, they will be transcoded into "H.264+AAC in web streaming friendly MP4 container" format and saved as ```videos/converted/YYYY/YYYY-MM/YYYYMMDD_<original_file_name>.mp4``` in the destination directory. In the case that the compression ratio of the transcoding is greater than 80%, the original file will be simply re-packaged rather than transcoded.

To Pause and resume processing after the initial copying has already been done, you can just use `CTRL-C` and then re-run the command line with the first argument (the input/source dir) changed to `-`.

