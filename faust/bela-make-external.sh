#!/bin/bash

file=$1
tmpFile=${file/.ext/}
name=${tmpFile/.cpp/}
outFile="../${name}~.pd_linux"

cp $file $tmpFile
clang++ -std=c++11 -O3 -mtune=cortex-a8 -mfloat-abi=hard  -ftree-vectorize -ffast-math  -I /usr/local/include/libpd/ -fPIC -shared -Dmydsp=$name -o $outFile $tmpFile
rm $tmpFile
