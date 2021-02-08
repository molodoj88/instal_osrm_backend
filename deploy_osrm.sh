#!/bin/bash

OSRM_IMAGE=osrm/osrm-backend
MAPS=maps
EXTRACTS_FILEPATH=""
EXPOSED_PORT=5000
CONATAINER_NAME=osrm-backend

# Get command line arguments:
while getopts f:p: flag
do
    case "${flag}" in
        p) EXPOSED_PORT=${OPTARG};;
        f) EXTRACTS_FILEPATH=${OPTARG};;
    esac
done

if [ "$EXTRACTS_FILEPATH" == "" ]; then
    echo "Please provide url for map extracts by -e option, or path to file by -f option"
    exit 1
fi

# Get filename
MAPS_DEFAULT_FILENAME=$(basename "$EXTRACTS_FILEPATH")
# Get filename for extracted database
MAPS_EXTRACTED_FILENAME=$(echo $MAPS_DEFAULT_FILENAME | sed 's/\./\n/g' | head -n 1).osrm

# Install osrm-backend
echo "Starting osrm-backend installation"

# Create directory for maps:
mkdir -p $MAPS

# Copy extracts to maps dir
echo Copying $EXTRACTS_FILEPATH to $MAPS
echo "y" | cp -f $EXTRACTS_FILEPATH $MAPS/

# Pull osrm-backend image:
docker pull $OSRM_IMAGE

# Preprocess extracts with cars profile:
docker run -t -v "${PWD}/$MAPS:/data" $OSRM_IMAGE osrm-extract -p /opt/car.lua /data/$MAPS_DEFAULT_FILENAME
docker run -t -v "${PWD}/$MAPS:/data" $OSRM_IMAGE osrm-partition /data/$MAPS_EXTRACTED_FILENAME
docker run -t -v "${PWD}/$MAPS:/data" $OSRM_IMAGE osrm-customize /data/$MAPS_EXTRACTED_FILENAME

# Start main container:
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
echo '    curl "http://127.0.0.1:$EXPOSED_PORT/route/v1/driving/44.505701,48.699783;44.482893,48.686069" | jq'