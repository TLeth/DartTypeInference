#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."
dartDir=$(which dart)
dart --enable-vm-service --pause-isolates-on-start -c "bin/analyze.dart" --dart-sdk ${dartDir%bin/dart} -o $1
