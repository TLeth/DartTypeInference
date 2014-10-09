#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

dartDir=$(which dart)
rm log
(for f in $(ls tests/)
do


  strip.dart tests/$f > tmp.dart
  
  dart ./bin/analyze.dart --dart-sdk ${dartDir%bin/dart} tmp.dart
  
  

  if [ $(diff <(dartfmt tests/$f) <(dartfmt tmp.dart) | wc -l) -eq 0 ]
  then echo -e $f '\033[0;32mPass\033[0m'
  else 
      echo -e $f '\033[0;31mFail\033[0m'
      echo $f >> log
      echo "------------------------------" >> log
      echo "got" >> log
      cat tmp.dart >> log
      printf "\n\n" >> log
      echo "expected" >> log
      cat tests/$f >> log
      printf "\n\n" >> log
      echo "diff" >> log
      diff <(cat tests/$f) <(cat tmp.dart) >> log
      printf "\n\n" >> log
  fi

 

  rm tmp.dart
  
done)|column -t
