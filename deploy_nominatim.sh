#!/bin/bash

NOMINATIM_IMAGE=mediagis/nominatim
DATA=nominatim_data
EXPOSED_PORT=7070
EXTRACTS_FILEPATH=""
CONATAINER_NAME=nominatim
THREADS=2

# Check if no arguments passed to script
if [ -z "$*" ]; then
	echo "No arguments found!"
    print_help
fi

# Get command line arguments:
while getopts f:p:c: flag
do
    case "${flag}" in
        p) EXPOSED_PORT=${OPTARG};;
        f) EXTRACTS_FILEPATH=${OPTARG};;
        c) THREADS=${OPTARG}
    esac
done

echo Threads: $THREADS

# Install nominatim
echo "Starting nominatim installation"

# 1. Create directory for maps:
mkdir -p $DATA

if [ "$EXTRACTS_FILEPATH" != "" ]; then
    MAPS_DEFAULT_FILENAME=$(basename "$EXTRACTS_FILEPATH")
    echo "y" | cp -f $EXTRACTS_FILEPATH $DATA/$MAPS_DEFAULT_FILENAME
else
    echo "Please provide extracts file with -f option"
    exit 1
fi

docker pull $NOMINATIM_IMAGE
docker run -t -v "${PWD}/${DATA}:/data" mediagis/nominatim sh /app/init.sh /data/$MAPS_DEFAULT_FILENAME postgresdata $THREADS
docker run --restart=always -p 6432:5432 -p $EXPOSED_PORT:8080 -d --name nominatim -v ${PWD}/${DATA}/postgresdata:/var/lib/postgresql/12/main mediagis/nominatim bash /app/start.sh
