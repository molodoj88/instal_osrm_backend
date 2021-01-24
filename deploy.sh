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

OSRM_IMAGE=osrm/osrm-backend
MAPS=maps
EXTRACTS_URL=""
EXTRACTS_FILEPATH=""
EXPOSED_PORT=5000
CONATAINER_NAME=osrm-backend

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

# Get filename from url:
if [ "$EXTRACTS_URL" != "" ]; then
    MAPS_DEFAULT_FILENAME=$(basename "$EXTRACTS_URL")
else
    MAPS_DEFAULT_FILENAME=$(basename "$EXTRACTS_FILEPATH")
fi

MAPS_EXTRACTED_FILENAME=$(echo $MAPS_DEFAULT_FILENAME | sed 's/\./\n/g' | head -n 1).osrm


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

# Install osrm-backend
echo "Starting osrm-backend installation"

# 1. Create directory for maps:
mkdir -p $MAPS

# 2. Download extracts (or copy file if -f option is provided):
if [ "$EXTRACTS_FILEPATH" != "" ]; then
    echo "y" | cp -f $EXTRACTS_FILEPATH $MAPS/$MAPS_DEFAULT_FILENAME
else
    wget -P $MAPS $EXTRACTS_URL
    if [ $? -ne 0 ]; then
        echo "Can't download extracts file"
        exit 1
    fi
fi

# 3. Pull osrm-backend image:
docker pull $OSRM_IMAGE

# 4. Preprocess extracts with cars profile:
docker run -t -v "${PWD}/$MAPS:/data" $OSRM_IMAGE osrm-extract -p /opt/car.lua /data/$MAPS_DEFAULT_FILENAME
docker run -t -v "${PWD}/$MAPS:/data" $OSRM_IMAGE osrm-partition /data/$MAPS_EXTRACTED_FILENAME
docker run -t -v "${PWD}/$MAPS:/data" $OSRM_IMAGE osrm-customize /data/$MAPS_EXTRACTED_FILENAME

# 5. Start main container:
docker run -t -d -p $EXPOSED_PORT:5000 -v "${PWD}/$MAPS:/data" --name $CONATAINER_NAME --restart always $OSRM_IMAGE osrm-routed --algorithm mld /data/$MAPS_EXTRACTED_FILENAME
if [ $? -ne 0 ]; then
    echo "Can't start osrm server. See logs above ^"
    exit 1
fi

echo Cleanup unused containers...
while IFS= read -r line; do
    container=$(echo $line | sed 's/\ /\n/g' | head -n 1)
    docker rm $container
done <<< "$(docker ps -a | grep osrm | grep Exited)"
echo Done!
echo

echo "Server successfully started on port $EXPOSED_PORT"
echo "You can check if it works with a next query, for example:"
echo '    curl "http://127.0.0.1:5000/route/v1/driving/44.505701,48.699783;44.482893,48.686069" | jq'
