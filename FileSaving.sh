#!/bin/bash

outputDirectory="./extracted/"

# verify that at least one argument was passed
if [ $# -eq 0 ]; then
    echo "error : no argument was passed."
    exit 1
fi

# verify the path of each argument
for ((i = 1; i <= $#; i++)); do
    path="${!i}"
    if [ ! -e "$path" ]; then
        echo "file <$path> does not exist"
        exit 1
    fi
done

# create the output directory
mkdir -p ./extracted

# now, compress
for ((i = 1; i <= $#; i++)); do
    path="${!i}"
    name=$(basename "${path}")
    date=$(date +%Y-%m-%d_%H:%M:%S)
    if command -v tar >/dev/null 2>&1 ; then
        tar -czf "${outputDirectory}${name}_${date}.tar.gz" $path
    elif  command -v bsdtar >/dev/null 2>&1 ; then
        tar -czf "${outputDirectory}${name}_${date}.tar.gz" $path
    else 
        echo "neither tar nor bsdtar is installed. install one of them to proceed."
        exit 1
    fi
done
        