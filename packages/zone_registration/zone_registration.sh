#!/bin/bash
#
# Purpose:
#   Create, update, or delete a date-based zone-registration record in a
#   semicolon-separated CSV file. The script is intended for calls from Home
#   Assistant, but can also be used directly from a Bash shell.
#
# Behavior:
#   - Creates the target file with a header when it does not exist.
#   - Updates the Minutes, Last, Review, and Comment fields for an existing date.
#   - Appends a new record with the current time when the date is not present.
#   - Removes all records matching --delete DATE when deletion is requested.
#   - Keeps the existing CSV format and does not create backups.
#
# Usage:
#   zone_registration.sh [options] FILENAME
#   zone_registration.sh --delete DATE [options] FILENAME
#
# Options:
#   -e, --entry MODE       Entry mode: auto or manual (default: manual).
#   -t, --minutes VALUE    Duration in minutes (default: 0).
#   -f, --date DATE        Record date (default: today).
#   -r, --review VALUE     Review status: Y or N (default: empty).
#   -c, --comment TEXT     Record comment (default: empty).
#   -d, --directory DIR    Directory containing FILENAME (default: current).
#       --delete DATE      Remove records for DATE instead of updating.
#   -h, --help             Display usage information.
#   -v, --version          Display the script version.
#
# CSV columns:
#   Date;Minutes;First;Last;Review;Entry;Comment
#
# Inputs / environment:
#   - FILENAME is the target CSV file name or path.
#   - DATE values must be accepted by GNU date -d.
#   - No environment variables are required or read.
#
# Outputs / side effects:
#   - Writes the target CSV file in place through a temporary file.
#   - Requires write access to the target directory.
#   - Uses the local system date and time for default and new-record values.
#
# Prerequisites:
#   Bash, GNU date, realpath, mktemp, awk, and a writable target directory.
#
# Version:
#   1.0.0
#
# Changelog:
#   1.0.0 - Initial versioned CLI release.


# Default values for arguments
VERSION="1.0.0"
DATE=$(date +%F)
TIME=$(date +%T)
ENTRY="manual"
MINUTES=0
REVIEW=""
COMMENT=""
WORKING_DIR="."
ARGS_NUM=${#}
FILENAME=${*: -1} # last command line argument 
DELETE=0


# Function to display syntax
display_syntax() {
  echo "Syntax: $0 [[-f date] [-e entry] [-t minutes] [-r review] [-c comment] [-d directory]] [--delete date] filename"
  echo "Options:"
  echo "  -e, --entry      Set the entry mode (default: manual)"
  echo "  -t, --minutes    Set the minutes (default: 0)"
  echo "  -f, --date       Set the date (default: today)"
  echo "  -r, --review     Set the review (default: empty)"
  echo "  -c, --comment    Set the comment (default: empty)"
  echo "  -d, --directory  Set the working directory (default: current directory)"
  echo "  --delete         Remove a date"
  echo "  -v, --version    Display the script version"
  exit 1
}


# Precheck
if [[ ${ARGS_NUM} -eq 0 ]]; then
  echo "Error: No arguments given. Filename must be given."
  exit 1
fi

if [[ "${1}" == "-v" || "${1}" == "--version" ]]; then
  echo "${VERSION}"
  exit 0
fi



# Parse optional arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--entry)
      if [[ "${2:0:1}" == "-" || -z $2 ]]; then # if first char in $2 is - or $2 is not defined then option was supplied without argument
        # Default value is used
        shift
      elif [[ "${2}" != "auto" && "${2}" != "manual" ]]; then
        echo "Error: Entry mode must be either 'auto' or 'manual'."
        exit 1
      else
        ENTRY=$2
        shift 2
      fi
      ;;
    -f|--date)
      if [[ "${2:0:1}" == "-" || -z $2 ]]; then # if first char in $2 is - or $2 is not defined then option was supplied without argument
        # Default value is used
        shift
      elif [[ $(date -d "${2}" 2> /dev/null) ]]; then # test if date is valid
        DATE=$2
        shift 2
      else
        echo "Error: Could not parse argument. Expected a date, got: '${2}'"
        exit 1
      fi
      ;;
    -t|--minutes)
      if [[ "${2:0:1}" == "-" || -z $2 ]]; then # if first char in $2 is - or $2 is not defined then option was supplied without argument
        # Default value is used
        shift
      elif [[ "$2" =~ ^[0-9]+([.,][0-9]+)?$ ]]; then
        MINUTES="$2"
        shift 2
      else
        echo "Error: Could not parse argument. Expected an numeric value, got: '${2}'"
        exit 1
      fi
      ;;
    -r|--review)
      if [[ "${2:0:1}" == "-" || -z $2 ]]; then # if first char in $2 is - or $2 is not defined then option was supplied without argument
        # Default value is used
        shift
      elif [[ "${2}" != "Y" && "${2}" != "N" ]]; then
        echo "Error: Review must be either 'Y' or 'N'."
        exit 1
      else
        REVIEW="$2"
        shift 2
      fi
      ;;
    -c|--comment)
      if [[ "${2:0:1}" == "-" || -z $2 ]]; then # if first char in $2 is - or $2 is not defined then option was supplied without argument
        # Default value is used
        shift
      else
        COMMENT="$2"
        shift 2
      fi
      ;;
    -d|--directory)
      if [[ "${2:0:1}" == "-" || -z $2 ]]; then # if first char in $2 is - or $2 is not defined then option was supplied without argument
        # Default value is used
        shift
      elif [[ ! -d ${2} ]]; then # $2 is not a directory
        echo "Error: Could not parse argument. \"${2}\" is not a directory"
        exit 1
      else
        WORKING_DIR=$(realpath "$2")
        shift 2
      fi
      ;;
    --delete)
      if [[ $(date -d "${2}" 2> /dev/null) ]]; then # test if date is valid
        DATE=$2
        DELETE=1
        shift 2
      else
        echo "Error: Could not parse argument. Expected a date, got: \"${2}\""
        exit 1
      fi
      ;;
    -h|--help)
      display_syntax
      ;;
    -v|--version)
      echo "${VERSION}"
      exit 0
      ;;
    *)
      if [[ ! "$1" == "${FILENAME}" ]] ; then 
        echo "Unknown option: $1"
        exit 1
      else 
        shift
      fi
      ;;
  esac
done


# Resolve real directory and filenames & check if the requested file exists.
FILE_DIR=$(dirname $(realpath "${WORKING_DIR}/${FILENAME}"))
FILENAME=${FILENAME##*/}
FILENAME="${FILE_DIR}/${FILENAME}"

if [[ ! -f ${FILENAME} ]]; then # file is in scriptdir or specific path to file supplied
  # If the file does not exist, create it with the header
  echo "Date;Minutes;First;Last;Review;Entry;Comment" > "${FILENAME}"
fi


# Create a temporary file using mktemp
TMP_FILE=$(mktemp)


# Test if in delete mode
if [ ${DELETE} -eq 1 ]; then
  # remove date from file
  echo Removing date ${DATE} from 
  awk "!/${DATE}/" "${FILENAME}" > "${TMP_FILE}" && mv "${TMP_FILE}" "${FILENAME}"
else
  # Update CSV file
  awk -v DATE="${DATE}" -v TIME="${TIME}" -v MINUTES="${MINUTES}" -v ENTRY="${ENTRY}" -v REVIEW="${REVIEW}" -v COMMENT="${COMMENT}" -F';' 'BEGIN{OFS=";"} $1==DATE {$2=MINUTES; $4=TIME; $5=REVIEW; $7=COMMENT; found=1} {print} END{if (!found) print DATE ";" MINUTES ";" TIME ";" TIME ";" REVIEW ";" ENTRY ";" COMMENT}' "$FILENAME" >  "$TMP_FILE" && mv "$TMP_FILE" "$FILENAME"
fi
