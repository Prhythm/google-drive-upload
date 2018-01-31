#!/bin/bash

# Empty google drive trash

#!/bin/bashset -e

#Configuration variables
CLIENT_ID=""
CLIENT_SECRET=""
REFRESH_TOKEN=""
SCOPE=${SCOPE:-"https://docs.google.com/feeds"}

#Internal variable
ACCESS_TOKEN=""
curl_args=""

DIR="$( cd "$( dirname "$( readlink "${BASH_SOURCE[0]}" )" )" && pwd )"

if [ -e $HOME/.googledrive.conf ]
then
    . $HOME/.googledrive.conf
fi

PROGNAME=${0##*/}
SHORTOPTS="vhr:C:z:" 
LONGOPTS="verbose,help,config:" 

set -o errexit -o noclobber -o pipefail #-o nounset 
OPTS=$(getopt -s bash --options $SHORTOPTS --longoptions $LONGOPTS --name $PROGNAME -- "$@" ) 

# script to parse the input arguments
#if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

VERBOSE=false
HELP=false
CONFIG=""

while true; do
  case "$1" in
    -v | --verbose ) VERBOSE=true;curl_args="--progress"; shift ;;
    -z | --config ) CONFIG="$2"; shift 2 ;;
    -- ) shift; break ;;
    * )  break ;;
  esac
done

if [ ! -z "$CONFIG" ]
	then
	if [ -e "$CONFIG" ]
	then
    	. $CONFIG
	fi
	if [ ! -z "$ROOTDIR" ]
		then
		ROOT_FOLDER="$ROOTDIR"
	fi

fi

# Method to extract data from json response
function jsonValue() {
KEY=$1
num=$2
awk -F"[,:}][^://]" '{for(i=1;i<=NF;i++){if($i~/\042'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p | sed -e 's/[}]*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[,]*$//' 
}

function log() {
	if [ "$VERBOSE" = true ]; then
		echo -e "${1}"
	fi
}

# Method to empty trash in google drive. Requires access token.
function emptyTrash(){
    EMPTY_TRASH_RESPONSE=`/usr/bin/curl \
        					--silent \
                            -X DELETE \
        					-H "Authorization: Bearer ${ACCESS_TOKEN}" \
                            "https://www.googleapis.com/drive/v2/files/trash"`
    log "$EMPTY_TRASH_RESPONSE"
}

old_umask=`umask`
umask 0077

if [ -z "$CLIENT_ID" ]
then
    read -p "Client ID: " CLIENT_ID
    echo "CLIENT_ID=$CLIENT_ID" >> $HOME/.googledrive.conf
fi

if [ -z "$CLIENT_SECRET" ]
then
    read -p "Client Secret: " CLIENT_SECRET
    echo "CLIENT_SECRET=$CLIENT_SECRET" >> $HOME/.googledrive.conf
fi

if [ -z "$REFRESH_TOKEN" ]
then
    RESPONSE=`curl --silent "https://accounts.google.com/o/oauth2/device/code" --data "client_id=$CLIENT_ID&scope=$SCOPE"`
	DEVICE_CODE=`echo "$RESPONSE" | jsonValue "device_code"`
	USER_CODE=`echo "$RESPONSE" | jsonValue "user_code"`
	URL=`echo "$RESPONSE" | jsonValue "verification_url"`

	echo -n "Go to $URL and enter $USER_CODE to grant access to this application. Hit enter when done..."
	read

	RESPONSE=`curl --silent "https://accounts.google.com/o/oauth2/token" --data "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&code=$DEVICE_CODE&grant_type=http://oauth.net/grant_type/device/1.0"`

	ACCESS_TOKEN=`echo "$RESPONSE" | jsonValue access_token`
	REFRESH_TOKEN=`echo "$RESPONSE" | jsonValue refresh_token`

    echo "REFRESH_TOKEN=$REFRESH_TOKEN" >> $HOME/.googledrive.conf
fi

if [ -z "$ACCESS_TOKEN" ]
	then
	# Access token generation
	RESPONSE=`curl --silent "https://accounts.google.com/o/oauth2/token" --data "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&refresh_token=$REFRESH_TOKEN&grant_type=refresh_token"`
	ACCESS_TOKEN=`echo $RESPONSE | jsonValue access_token`
fi

emptyTrash
