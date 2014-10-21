#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."
dartDir=$(which dart)
dart --enable-vm-service --observe "bin/analyze.dart" --dart-sdk ${dartDir%bin/dart} $1
