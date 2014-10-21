#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

for f in $(cat $1/files.info)
do
	echo $f
	./tools/types.dart $1/$f $2/$f -find
done
