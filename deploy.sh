#!/bin/bash

function print_help () {
    # Print help message end exit
    echo
    echo Script uses next arguments:
    echo "    -h: show this help message"
    echo "    -e URL: url link to extracts file (for example: -e http://download.geofabrik.de/russia/south-fed-district-latest.osm.pbf)"
    echo "    -f FILE: full path to file with map extracts with .osm.pbf extension (for example /home/user/south-fed-district-latest.osm.pbf)"
    echo "    -p PORT: [optional] you may define port number on wich server will be exposed (for example: -p 7654). Default port is 5000"
    echo
    exit 0
}

# Check if no arguments passed to script
if [ -z "$*" ]; then
	echo "No arguments found!"
    print_help
fi

EXTRACTS_URL=""
EXTRACTS_FILEPATH=""

# Get command line arguments:
while getopts e:f:p:h flag
do
    case "${flag}" in
        h) print_help;;
        e) EXTRACTS_URL=${OPTARG};;
        p) EXPOSED_PORT=${OPTARG};;
        f) EXTRACTS_FILEPATH=${OPTARG};;
    esac
done

if [ "$EXTRACTS_URL" == "" ]; then
    if [ "$EXTRACTS_FILEPATH" == "" ]; then
        echo "Please provide url for map extracts by -e option, or path to file by -f option"
        exit 1
    fi
fi

function install_docker () {
    echo "Installing docker"
    DOCKER_SCRIPT_PATH=/tmp/get-docker.sh
    curl -fsSL https://get.docker.com -o $DOCKER_SCRIPT_PATH
    sh $DOCKER_SCRIPT_PATH
}

# Check if docker installed or no
dpkg -l | grep docker > /dev/null
case $? in
    0)
        echo docker is already installed
        ;;
    1)
        install_docker
        ;;
esac

if [ "$EXTRACTS_URL" != "" ]; then
    wget -P $MAPS $EXTRACTS_URL
    if [ $? -ne 0 ]; then
        echo "Can't download extracts file"
        exit 1
    fi
    MAPS_DEFAULT_FILENAME=$(basename "$EXTRACTS_URL")
    EXTRACTS_FILEPATH=/tmp/$MAPS_DEFAULT_FILENAME
fi

# Deploy osrm server
bash deploy_osrm.sh -p $EXPOSED_PORT -f $EXTRACTS_FILEPATH

# Deploy nominatim
# Define number of cores at first
THREADS=$(cat /proc/cpuinfo | grep -c processor)
bash deploy_nominatim.sh -f $EXTRACTS_FILEPATH -c $THREADS
