#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

dartDir=$(which dart)

for f in $(tools/dependency.dart --dart-sdk ${dartDir%bin/dart} $1)
do
    vardecl_transform.dart $f
done