#!/bin/bash -
#===============================================================================
#         USAGE: --help
#        AUTHOR: Sylvain S. (ResponSyS), mail@sylsau.com
#       CREATED: 03/24/2020 10:25:03 PM
#===============================================================================

# Enable strict mode in debug mode
[[ $DEBUG ]] && set -o nounset -o xtrace
set -o pipefail -o errexit -o errtrace
trap 'syl_exit_err "at ${FUNCNAME:-(top level)}:$LINENO"' ERR

readonly SCRIPT_NAME="${0##*/}"
readonly VERSION=20200328

# Format characters
readonly FMT_BOLD='\e[1m'
readonly FMT_UNDERL='\e[4m'
readonly FMT_OFF='\e[0m'
# Error codes
readonly ERR_WRONG_ARG=2
readonly ERR_NO_FILE=127
# Return value
RET=
# Temporary dir
readonly TMP_DIR="/tmp"

# Test if a file exists (dir or not)
# $1: path to file
syl_need_file() {
    [[ -e "$1" ]] || syl_exit_err "need '$1' (file not found)" $ERR_NO_FILE
}
# Test if a dir exists
# $1: path to dir
syl_need_dir() {
    [[ -d "$1" ]] || syl_exit_err "need '$1' (directory not found)" $ERR_NO_FILE
}
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
# Cd to script directory
syl_cd_workdir() {
    cd "$( dirname "$0" )" || syl_exit_err "Can't 'cd' into '$( dirname "$0" )'" $ERR_NO_FILE
    msyl_say "cd '$(pwd)'"
}
# Create tmp file
# $1: prefix for tmp file, $2: suffix (opt)
syl_mktemp() {
    [[ $1 ]] || syl_exit_err "${FUNCNAME[0]}: please specify a prefix for temporary file name" $ERR_WRONG_ARG
    readonly local PATT="$1-$USER-XXXX$2"
    RET="$( mktemp "${TMP_DIR}/$PATT" )" || syl_exit_err "can't create temporary file '$PATT' in '$TMP_DIR'" $ERR_NO_FILE
}
# Create tmp dir
# $1: prefix for tmp dir
syl_mktemp_dir() {
    [[ $1 ]] || syl_exit_err "${FUNCNAME[0]}: please specify a prefix for temporary directory name" $ERR_WRONG_ARG
    readonly local PATT="$1-$USER-XXXX"
    RET="$( mktemp -d "${TMP_DIR}/$PATT" )" || syl_exit_err "can't create temporary directory '${PATT}/' in '$TMP_DIR'" $ERR_NO_FILE
}

# Print help
show_help() {
    cat << EOF
$SCRIPT_NAME v$VERSION
    Simple handy script to optimize JPEG and PNG images in a flash. Really just a 
    wrapper around jpegoptim and pngquant. Saves a LOT of time for web assets 
    optimization.

REQUIREMENTS
    jpegoptim, pngquant, imagemagick

USAGE
    $SCRIPT_NAME [-q QUALITY] [-s SIZE] [-r] [-n] {IN_FILE} -o {OUT_FILE}

OPTIONS
    -q QUALITY      Defines quality of the conversion. QUALITY is a number from
                    0 to 100. Maps to jpegoptim '-m' and pngquant '--quality'.
                    [default = $OPT_QUALITY]
    -s SIZE         Defines size of the output image. Format: {width}x{height}.
                    You can specify both or just one of them.
    -r              Removes metadata from conversion. Maps to jpegoptim '-s' and
                    pngquant '--strip'.
    -n              Fake it, only prints commands.

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

AUTHOR
    Written by Sylvain Saubier (<https://kultu.fr>)

REPORTING BUGS
    Mail at: <feedback@sylsau.com>

EOF
}

OPT_IN=
OPT_OUT=
OPT_QUALITY=66
OPT_SIZE=
OPT_STRIP=
FILE_TMP=
FAKE=

main() {
    # check dependencies
    syl_need_cmd "convert"
    syl_need_cmd "jpegoptim"
    syl_need_cmd "pngquant"
    syl_need_dir "$TMP_DIR"
    syl_need_file "/dev/stdout"
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
            "-s")
                shift
                OPT_SIZE=$1
                ;;
            "-q")
                shift
                OPT_QUALITY=$1
                ;;
            "-r")
                OPT_STRIP=true
                ;;
            "-n")
                FAKE=echo
                ;;
            *)
                OPT_IN="$1"
        esac	# --- end of case ---
        # Delete $1
        shift
    done
    # check if in != out
    [[ "$OPT_IN" != "$OPT_OUT" ]] || syl_exit_err "output file needs to be different than input file" $ERR_WRONG_ARG
    if [[ -n "`echo "$OPT_OUT" | grep "jpe\?g$"`" ]]; then
        FORMAT_OUT=JPG
    elif [[ -n "`echo "$OPT_OUT" | grep "png$"`" ]]; then
        FORMAT_OUT=PNG
    else
        syl_exit_err "wrong format for input file" $ERR_WRONG_ARG
    fi
    syl_mktemp "$SCRIPT_NAME" ".$FORMAT_OUT"
    FILE_TMP="$RET"
    if [[ -n "$OPT_SIZE" ]]; then
        $FAKE convert "$OPT_IN" -quality 100 -resize "$OPT_SIZE" "$FILE_TMP"
    else
        $FAKE convert "$OPT_IN" -quality 100                     "$FILE_TMP"
    fi

    OUT_STREAM=">"
    if [[ "$FORMAT_OUT" = "JPG" ]]; then
        [[ "$OPT_STRIP" ]] && OPT_STRIP="-s"
        [[ "$FAKE" ]] && OPT_OUT="/dev/stdout"
        $FAKE jpegoptim "$FILE_TMP" $OPT_STRIP -m$OPT_QUALITY --stdout >"$OPT_OUT"
    elif [[ "$FORMAT_OUT" = "PNG" ]]; then
        [[ "$OPT_STRIP" ]] && OPT_STRIP="--strip"
        [[ "$FAKE" ]] && OPT_OUT="/dev/stdout"
        $FAKE pngquant "$FILE_TMP" $OPT_STRIP --quality $OPT_QUALITY   >"$OPT_OUT"
    else
        syl_exit_err "wrong format for input file" $ERR_WRONG_ARG
    fi

    msyl_say "All done!"
}

main "$@"

