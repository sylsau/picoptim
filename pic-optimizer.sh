#!/bin/bash -
#===============================================================================
#		  USAGE: --help
#		 AUTHOR: Sylvain S. (ResponSyS), mail@sylsau.com
#		CREATED: 03/24/2020 10:25:03 PM
#===============================================================================

# Enable strict mode in debug mode
[[ $DEBUG ]] && set -o nounset -o xtrace
set -o pipefail -o errexit -o errtrace
trap 'syl_exit_err "at ${FUNCNAME:-(top level)}:$LINENO"' ERR

readonly SCRIPT_NAME="${0##*/}"
readonly VERSION=20230629

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
	$SCRIPT_NAME FILE [-q QUALITY] [-c NCOLORS] [-s SIZE] [-r] [-n] -o OUT_FILE

OPTIONS
	-o, OUT_FILE 		Specifies output file name. Overwrites existing file.
	-q, --quality QUALITY	Defines quality of the output file. QUALITY is a number from
				0 to 99. Maps to jpegoptim '-m' and pngquant '--quality'.
				[default = $OPT_QUALITY]
	-c, --colors NCOLORS	Defines the number of colors to use for PNG output. Maps to 
				pngquant color argument. Overwrites the QUALITY parameter.
	-s, --resize SIZE	Defines size of the output image. Format: {width}x{height}.
				You can specify both or just one of them.
	-r, --strip		Removes metadata during conversion. Maps to jpegoptim '-s' and
				pngquant '--strip'.
	-n 			Fakes it, so it only prints commands.
	-v, --verbose		Be verbose.

EXAMPLES
	$ ./$SCRIPT_NAME IN.JPG -o OUT.JPG -r
		converts 'IN.JPG' to 'OUT.JPG' with ${OPT_QUALITY}% quality (default) and
		metadatas stripped
	$ ./$SCRIPT_NAME PIC.JPG -q 80 -s 1000x -o STATIC/IMG/PIC.JPG
		converts 'PIC.JPG' to 'STATIC/IMG/PIC.JPG' with 80% quality and resized
		to 1000px of width
	$ ./$SCRIPT_NAME WIP/PIC.PNG -s x500 -o static/IMG/OUT.JPG
		converts 'WIP/PIC.PNG' to 'static/IMG/OUT.JPG' with ${OPT_QUALITY}%
		quality and resized to 500px of height
	$ ./$SCRIPT_NAME /tmp/PIC.JPG -s 350x -c 32 -o static/IMG/OUT.PNG
		converts '/tmp/PIC.PNG' to 'static/IMG/OUT.PNG' sampled down to 32 colors
		and resized to 350px of width

AUTHOR
	Written by Sylvain Saubier (<https://sylsau.com>)

REPORTING BUGS
	Mail at: <feedback@sylsau.com>

EOF
}

OPT_IN=
OPT_OUT=
OPT_QUALITY=66
OPT_NCOLORS=
OPT_SIZE=
OPT_STRIP=
OPT_VERBOSE=
# Store conversion order (PNG->JPEG, etc.)
CONV_ORDER=(PNG JPEG)
FAKE=

main() {
	# check dependencies
	syl_need_cmd "$CONVERT"
	syl_need_cmd "$JPEGOPTIM"
	syl_need_cmd "$PNGQUANT"
	# check if at least 2 args
	[[ $# -ge 2 ]] || { show_help ; exit ; }
	# Parse arguments
	while [[ $# -ge 1 ]]; do
		case "$1" in
			"-h"|"--help")
				show_help
				exit
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
			"-r"|"--strip")
				OPT_STRIP=true
				;;
			"-v"|"--verbose")
				OPT_VERBOSE="--verbose"
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
	[[ "$OPT_IN" != "$OPT_OUT" ]] || syl_exit_err "output file needs to be different than input file" $ERR_WRONG_ARG
	[[ "$OPT_IN" && "$OPT_OUT" ]] || syl_exit_err "missing input or output file" $ERR_WRONG_ARG
	# check file formats
	if [[ "$OPT_IN" =~ [Jj][Pp][Ee]?[Gg]$ ]]; then
		CONV_ORDER[0]=JPEG
	elif [[ "$OPT_IN" =~ [Pp][Nn][Gg]$ ]]; then
		CONV_ORDER[0]=PNG
	else
		syl_exit_err "wrong format for input file" $ERR_WRONG_ARG
	fi
	if [[ "$OPT_OUT" =~ [Jj][Pp][Ee]?[Gg]$ ]]; then
		CONV_ORDER[1]=JPEG
	elif [[ "$OPT_OUT" =~ [Pp][Nn][Gg]$ ]]; then
		CONV_ORDER[1]=PNG
	else
		syl_exit_err "wrong format for output file" $ERR_WRONG_ARG
	fi

	[[ $FAKE ]] && msyl_say "Showing commands to be executed."

	# Deux situations : convert+jpegoptim pour jpg OU convert+pngquant pour png
	if [[ ${CONV_ORDER[1]} = "JPEG" ]]; then
		[[ "$OPT_STRIP" ]] && OPT_STRIP="-s"
		[[ "$OPT_QUALITY" ]] && OPT_QUALITY="-m$OPT_QUALITY"
		if [[ -z "$FAKE" ]]; then 
			$CONVERT "$OPT_IN" -quality 100 $OPT_SIZE JPEG:- | $JPEGOPTIM - $OPT_QUALITY $OPT_STRIP $OPT_VERBOSE >"$OPT_OUT"
		else echo """
			$CONVERT "$OPT_IN" -quality 100 $OPT_SIZE JPEG:- | $JPEGOPTIM - $OPT_QUALITY $OPT_STRIP $OPT_VERBOSE >"$OPT_OUT"
			"""
		fi
	elif [[ ${CONV_ORDER[1]} = "PNG" ]]; then
		[[ "$OPT_NCOLORS" ]] && OPT_QUALITY="" && msyl_say "quality parameter overwritten by color parameter" 
		[[ "$OPT_STRIP" ]] && OPT_STRIP="--strip"
		[[ "$OPT_QUALITY" ]] && OPT_QUALITY="--quality $OPT_QUALITY"
		if [[ -z "$FAKE" ]]; then 
			$CONVERT "$OPT_IN" -quality 100 $OPT_SIZE PNG:- | $PNGQUANT $OPT_NCOLORS - $OPT_QUALITY $OPT_STRIP $OPT_VERBOSE >"$OPT_OUT"
		else echo """
			$CONVERT "$OPT_IN" -quality 100 $OPT_SIZE PNG:- | $PNGQUANT $OPT_NCOLORS - $OPT_QUALITY $OPT_STRIP $OPT_VERBOSE >"$OPT_OUT"
			"""
		fi
	fi

	msyl_say "All done!"
}

main "$@"

