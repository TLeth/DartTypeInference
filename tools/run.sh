#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."
dartDir=$(which dart)
dart --old_gen_heap_size=4000m --enable-vm-service --observe "bin/analyze.dart" --dart-sdk ${dartDir%bin/dart} --skip-sdk --skip-packages $1
