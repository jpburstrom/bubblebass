#!/bin/bash

file=$1
outfile=${file/.dsp/\~.pd_darwin}

faust2puredata $file &&
cp "$outfile" ~/Library/Pd/
source=$(faust2puredata -tosource $file);
mv $source .
rm -r faust.*

