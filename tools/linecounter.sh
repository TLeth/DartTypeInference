#!/bin/bash

dartDir=$(which dart)

cd "`dirname \"$0\"`"
cd ".."

(while read line; do
	tmp=($line)
	entrydir=${tmp[0]}
	mainfile=${tmp[1]}
	entryfile=benchmarks/$entrydir/$mainfile
	files=$(./tools/dependency.dart --dart-sdk ${dartDir%bin/dart} $entryfile)
	echo $entrydir
	cat $files | wc -l
done)