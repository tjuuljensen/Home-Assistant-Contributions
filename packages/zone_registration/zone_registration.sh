#!/bin/bash
# 
# Torsten Juul-Jensen
# Date: 28 September 2023
#
# The script is made for registering entries in a CSV file based on input from Home Assistant.
# The file has the following fields:
# - Date (in ISO 8601 date format)
# - Minutes (numeric duration of time in zone)
# - First (first time registration, in ISO 8601 timestamp format)
# - Last (last time registration on record, in ISO 8601 timestamp format)
# - Review (Y, N or blank)
# - Entry (auto or manual)
# - Comment
# 
# Subsequent updates with same date will overwrite contents of Minutes, Entry, Last, Review and Comment.
#


# Default values for arguments
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
  echo "Syntax: $0 [[-f date] [-m entry] [-t minutes] [-r review] [-c comment] [-d directory]] [--delete date] filename"
  echo "Options:"
  echo "  -e, --entry      Set the entry mode (default: manual)"
  echo "  -t, --minutes    Set the minutes (default: 0)"
  echo "  -f, --date       Set the date (default: today)"
  echo "  -r, --review     Set the review (default: empty)"
  echo "  -c, --comment    Set the comment (default: empty)"
  echo "  -d, --directory  Set the working directory (default: current directory)"
  echo "  --delete         Remove a date"
  exit 1
}


# Precheck
if [[ ${ARGS_NUM} -eq 0 ]]; then
  echo "Error: No arguments given. Filename must be given."
  exit 1
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



