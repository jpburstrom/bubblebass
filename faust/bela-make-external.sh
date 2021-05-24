#!/bin/bash

file=$1
name=${file/.cpp/}
outFile="${name}~.pd_linux"

clang++ -std=c++11 -O3 -mtune=cortex-a8 -mfloat-abi=hard  -ftree-vectorize -ffast-math  -I /usr/local/include/libpd/ -fPIC -shared -Dmydsp=$name -o $outFile $file
