 #! /bin/bash

#
# Copyright 2018 Manfred Mueller-Spaeth (mamuesp) <fms1961@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR 
# A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# reads a single file, encodes it in base64 and transfers it viar "FS.Put"
# rpc call to the Mongoose device The lines are transferred one by one,
# so there is no problem with any chunk size limits

usage="Usage: mosPutFile.sh --src=<name> --dest=<name> [--p=<port>] [--verbose]"

handleSingleFile() {
	srcfile="$1"		# filename to transfer
	destfile="$2" 	# filename on the device
	port="$3"				# port used (to be able to use WS pors)
	verbose="$4" 		# verboce flag

	if [ -f "${srcfile}" ]
	then
		mimetype="$(file --mime-type -b $srcfile)"
		case "${mimetype}" in
			application/octet-stream | \
			application/x-gzip | \
			text/html | \
			text/plain | \
			text/css | \
			text/json | \
			text/javascript )
				base=$(basename "$srcfile") 
				destfile=$(printf '%s/%s' "$destfile" "$base")
			;;
			*)
				echo "Not an accepted file type! ($mimetype -> $base)"
				return 1
			;;
	 esac		
	fi

	# if no destination file is given, we try to use the source file name
	if [[ -z "${destfile// }" ]]
		then 
		destfile="$srcfile"
	fi

	# check, if the source file exists
	[ -f "$srcfile" ] || die "File $srcfile does not exist"
	
	# encode the file and gather the base64 encoeded data
	b64data="$(openssl base64 -in $srcfile)";
	lineNum=$(echo -n "$b64data" | grep -c '^')
	counter=0
	append=false
	transferred=0
	echo Copy "$srcfile" to "$destfile" ...
  
	# now traverse the base64 data line by line
	while IFS= read -r line
	do
		# prepare the argument JSON string for the RPC call
		jsondata=$(printf '{\"filename\": \"%s\", \"data\": \"%s\", \"append\": %b}' "$destfile" "$line" "$append");
#		echo $jsondata
		# call the Mongoose-OS device via RPC and transfer the data
		msg="$(~/.mos/bin/mos --timeout 30s --port="$port" call FS.Put "$jsondata")";
		# some errorhandling and a "progress bar" ...
		if [[ "$msg" == "null" ]]
		then
			counter=$((counter+1))
  		prog=$(echo "(($counter*100.0)/$lineNum)" | bc)
  		chunksize=${#line}
  		transferred=$((transferred+chunksize))
			printf "\rBytes sent: [$transferred] (${prog}%%)"
		else
		  # something happened ...
			echo "$msg"
			return 1
		fi	
		append=true
	done < <(printf '%s\n' "$b64data")
	echo "FS.Put call finished!"
}

# little function do leave the script completely
die () {
    echo >&2 "$@"
    exit 1
}

# here starts the main part
# at first we check the given arguments, in faulty cases some error
# messages are shown
if [ $# -eq 0 ]
  then
    die "$usage"
fi
port="${MOS_PORT}"
fiilename=
devfile=
verbose=0

while [ "$#" -gt 0 ]; do
  case "$1" in
#   -f) filename="$2"; shift 2;;
#   -p) port="$2"; shift 2;;
#		-d) devfile="$2"; shift 2;;
#		-V) verbose=1; shift 1;;
	
    --src=*) filename="${1#*=}"; shift 1;;
    --dest=*) devfile="${1#*=}"; shift 1;;
    --port=*) port="${1#*=}"; shift 1;;
    --verbose=*) verbose=1; shift 1;;
    --src | --dest) echo "$1 requires an argument" >&2; echo $usage >&2; exit 1;;

    -*) echo "unknown option: $1" >&2; echo $usage >&2; exit 1;;
    *) handle_argument "$1"; shift 1;;
  esac
done

filename="${filename// }"

# there is a file name
if [[ -z "$filename" ]]
then
	die "$usage"
fi

if [ -d "$filename" ]
then
	# if it's a directory, we traverse the directory and handle all accepted
	# files (tested via MIME type)
	ls -d -1 $PWD/$filename/*.* | while read -r file;
	do
		handleSingleFile "$file" "$devfile" "$port" "$verbose"
	done
elif [ -f "$filename" ]
then
		handleSingleFile "$filename" "$devfile" "$port" "$verbose"
else
	echo "No file found! ($filename)"
	echo "$usage"
fi
