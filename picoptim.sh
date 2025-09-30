#!/bin/bash -
#===============================================================================
#		  USAGE: --help
#		 AUTHOR: Sylvain S. (ResponSyS), mail@sylsau.com
#		CREATED: 03/24/2020 10:25:03 PM
#===============================================================================

# TODO
# - implement the -i option

# Enable strict mode in debug mode
[[ $DEBUG ]] && set -o nounset -o xtrace
set -o pipefail -o errexit -o errtrace
trap 'syl_exit_err "at ${FUNCNAME:-(top level)}:$LINENO"' ERR

readonly SCRIPT_NAME="${0##*/}"
readonly VERSION=20241113

# Format characters
readonly FMT_BOLD='\e[1m'
readonly FMT_UNDERL='\e[4m'
readonly FMT_OFF='\e[0m'
# Error codes
readonly ERR_WRONG_ARG=2
readonly ERR_NO_FILE=127
# Return value
RET=
# Commands
CONVERT=convert
PNGQUANT=pngquant
JPEGOPTIM=jpegoptim

# Test if a command exists
# $1: command
syl_need_cmd() {
	command -v "$1" >/dev/null 2>&1
	[[ $? -eq 0 ]] || syl_exit_err "need '$1' (command not found)" $ERR_NO_FILE
}
# $1: message
msyl_say() {
	echo -e "$SCRIPT_NAME: $1"
	#echo -e "$1"
}
# $1: debug message
syl_say_debug() {
	[[ ! "$DEBUG" ]] || echo -e "[DEBUG] $1"
}
# Exit with message and provided error code
# $1: error message, $2: return code
syl_exit_err() {
	msyl_say "${FMT_BOLD}ERROR${FMT_OFF}: $1" >&2
	exit $2
}

# Print help
show_help() {
	cat << EOF
$SCRIPT_NAME v$VERSION
	Powerful script to optimize JPEG and PNG images in a flash.
	Really just a wrapper around jpegoptim and pngquant. Saves a LOT of time
	for web assets optimization.

REQUIREMENTS
	imagemagick, jpegoptim, pngquant

USAGE
	$SCRIPT_NAME FILE  (-o OUT_FILE | -f FORMAT) [-q QUALITY] [-c NCOLORS] [-s SIZE] [-r] [-b SUFFIX] [-n] [-v]

OPTIONS
	-o OUT_FILE 		Specifies output file name. Overwrites existing file.
	-f FORMAT 		Specifies output format ("jpe?g" or "png"). Creates backup
				file if needed.
	-q, --quality QUALITY	Defines quality of the output file. QUALITY is a number from
				0 to 99. Maps to jpegoptim '-m' and pngquant '--quality'.
				[default: $OPT_QUALITY]
	-c, --colors NCOLORS	Defines the number of colors to use for PNG output. Maps to 
				pngquant 'ncolors' argument. Overwrites QUALITY.
				[default: $OPT_NCOLORS]
	-s, --resize SIZE	Defines size of the output image. Format: {width}x{height}.
				You can specify both or just one of them.
	-k, --no-strip		Keeps metadata during conversion. Disable jpegoptim's '-s' and
				pngquant's '--strip'.
				[default: (on)]
	-b, --backup-suffix SUFFIX
				Sets the backup suffix.
				[default: $OPT_BKP_SUFFIX]
	-i, -in-place		Disable backup (in-place editing).
	-n 			Fakes it, so it only prints commands.
	-v, --verbose		Be verbose.

EXAMPLES
	$ ./$SCRIPT_NAME IN.jpg -f jpg
		converts 'IN.jpg' in place with ${OPT_QUALITY}% quality (default),
		strip metadatas and create IN$OPT_BKP_SUFFIX.jpg backup file.
	$ ./$SCRIPT_NAME PIC.JPG -q 80 -s 1000x -o STATIC/IMG/PIC.JPG -k
		converts 'PIC.JPG' to 'STATIC/IMG/PIC.JPG' with 80% quality, resized
		to 1000px of width, with metadatas kept intact.
	$ ./$SCRIPT_NAME WIP/PIC.PNG -s x500 -o static/IMG/OUT.JPG
		converts 'WIP/PIC.PNG' to 'static/IMG/OUT.JPG' with ${OPT_QUALITY}%
		quality, resized to 500px of height, with metadatas stripped.
	$ ./$SCRIPT_NAME /tmp/PIC.JPG -s 350x -o static/IMG/OUT.PNG
		converts '/tmp/PIC.PNG' to 'static/IMG/OUT.PNG' sampled down to
		32 colors, resized to 350px of width, with metadatas stripped.

AUTHOR
	Written by Sylvain Saubier (<https://sylsau.com>)

REPORTING BUGS
	Mail at: <feedback@sylsau.com>

EOF
}

OPT_IN=
OPT_FMT=
OPT_OUT=
OPT_NO_BKP=
OPT_BKP_SUFFIX=_ORIG
OPT_ORIG=
OPT_QUALITY=66
OPT_NCOLORS=32
OPT_SIZE=
OPT_KEEP=
OPT_VERBOSE=
# Store conversion order (PNG->JPEG, etc.)
CONV_ORDER=(PNG JPEG)
FAKE=

# check dependencies
syl_need_cmd "$CONVERT"
syl_need_cmd "$JPEGOPTIM"
syl_need_cmd "$PNGQUANT"
## check if at least 2 args
#[[ $# -ge 2 ]] || { show_help ; exit ; }
# Parse arguments
while [[ $# -ge 1 ]]; do
	case "$1" in
		"-h"|"--help")
			show_help
			exit
			;;
		"-f")
			shift
			OPT_FMT="$1"
			;;
		"-o")
			shift
			OPT_OUT="$1"
			;;
		"-s"|"--resize")
			shift
			OPT_SIZE="-resize $1"
			;;
		"-q"|"--quality")
			shift
			OPT_QUALITY=$1
			;;
		"-c"|"--colors")
			shift
			OPT_NCOLORS=$1
			;;
		"-k"|"--no-strip")
			OPT_KEEP=true
			;;
		"-b"|"--backup-suffix")
			shift
			OPT_BKP_SUFFIX=$1
			;;
		"-i"|"--in-place")
			OPT_NO_BKP=true
			;;
		"-v"|"--verbose")
			OPT_VERBOSE="-v"
			;;
		"-n")
			FAKE=true
			;;
		*)
			OPT_IN="$1"
	esac	# --- end of case ---
	# Delete $1
	shift
done

# Check if in != out
[[ "$OPT_IN" ]] || syl_exit_err "missing input file" $ERR_WRONG_ARG
[[ "$OPT_IN" != "$OPT_OUT" ]] || syl_exit_err "output file needs to be different than input file" $ERR_WRONG_ARG
[[ "$OPT_FMT" && "$OPT_OUT" ]] && syl_exit_err "need either format or output file, not both" $ERR_WRONG_ARG
[[ "$OPT_FMT" ]] || [[ "$OPT_OUT" ]] || syl_exit_err "need either format or output file, not both" $ERR_WRONG_ARG
# Check file formats
if [[ "$OPT_IN" =~ [Jj][Pp][Ee]?[Gg]$ ]]; then
	CONV_ORDER[0]=JPEG
elif [[ "$OPT_IN" =~ [Pp][Nn][Gg]$ ]]; then
	CONV_ORDER[0]=PNG
else
	syl_exit_err "wrong format for input file" $ERR_WRONG_ARG
fi

# Process format string if set
[[ "$OPT_FMT" ]] && {
	OPT_OUT="${OPT_IN%.*}.$OPT_FMT"
	# Si in et out sont les mêmes
	[[ "$OPT_IN" = "$OPT_OUT" ]] && { 
		# Faire copie ORIG
		OPT_ORIG="${OPT_IN%.*}${OPT_BKP_SUFFIX}.${OPT_IN##*.}"
		if [[ -z "$FAKE" ]]; then
			cp $OPT_VERBOSE $OPT_IN $OPT_ORIG
		else echo \
			"""cp $OPT_VERBOSE $OPT_IN $OPT_ORIG """
		fi
		OPT_IN="${OPT_ORIG}"
		msyl_say "a backup ${OPT_IN} file will be created."
	}
}
if [[ "$OPT_OUT" =~ [Jj][Pp][Ee]?[Gg]$ ]]; then
	CONV_ORDER[1]=JPEG
elif [[ "$OPT_OUT" =~ [Pp][Nn][Gg]$ ]]; then
	CONV_ORDER[1]=PNG
else
	syl_exit_err "wrong format for output file or format string" $ERR_WRONG_ARG
fi

[[ $FAKE ]] && msyl_say "Showing commands to be executed."

# Deux situations : convert+jpegoptim pour jpg OU convert+pngquant pour png
if [[ ${CONV_ORDER[1]} = "JPEG" ]]; then
	[[ ! "$OPT_KEEP" ]] && OPT_KEEP="-s"
	[[ "$OPT_QUALITY" ]] && OPT_QUALITY="-m$OPT_QUALITY"
	if [[ -z "$FAKE" ]]; then 
		$CONVERT "$OPT_IN" -quality 100 $OPT_SIZE JPEG:- | $JPEGOPTIM - $OPT_QUALITY $OPT_KEEP $OPT_VERBOSE >"$OPT_OUT"
	else echo \
		"""$CONVERT "$OPT_IN" -quality 100 $OPT_SIZE JPEG:- | $JPEGOPTIM - $OPT_QUALITY $OPT_KEEP $OPT_VERBOSE >"$OPT_OUT""""
	fi
elif [[ ${CONV_ORDER[1]} = "PNG" ]]; then
	[[ ! "$OPT_KEEP" ]] && OPT_KEEP="--strip"
	[[ "$OPT_QUALITY" ]] && OPT_QUALITY="--quality $OPT_QUALITY"
	[[ "$OPT_NCOLORS" ]] && OPT_QUALITY="" #&& msyl_say "quality parameter overwritten by color parameter" 
	if [[ -z "$FAKE" ]]; then 
		$CONVERT "$OPT_IN" -quality 100 $OPT_SIZE PNG:- | $PNGQUANT $OPT_NCOLORS - $OPT_QUALITY $OPT_KEEP $OPT_VERBOSE >"$OPT_OUT"
	else echo \
		"""$CONVERT "$OPT_IN" -quality 100 $OPT_SIZE PNG:- | $PNGQUANT $OPT_NCOLORS - $OPT_QUALITY $OPT_KEEP $OPT_VERBOSE >"$OPT_OUT" """
	fi
fi

msyl_say "All done!"
