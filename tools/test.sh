#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

dartDir=$(which dart)
rm -f log

for f in $(ls tests/cases/)
do
    if [ ! -f tests/.stripped/$f ]; then
        strip.dart tests/cases/$f > tests/.stripped/$f
        dartfmt -w tests/.stripped/$f
    fi
    
    if [ tests/cases/$f -nt tests/.stripped/$f ]; then
        strip.dart tests/cases/$f > tests/.stripped/$f
        dartfmt -w tests/.stripped/$f
    fi
done

rm -f tests/output/*.dart
cp tests/.stripped/*.dart tests/output/

dart ./bin/analyze.dart --dart-sdk ${dartDir%bin/dart} tests/output/tests.dart

(for f in $(ls tests/cases/)
do
  dartfmt -w tests/output/$f

  if [ $(diff <(cat tests/cases/$f) <(cat tests/output/$f) | wc -l) -eq 0 ]
  then echo -e $f '\033[0;32mPass\033[0m'
  else 
      echo -e $f '\033[0;31mFail\033[0m'
      echo $f >> log
      echo "------------------------------" >> log
      echo "got" >> log
      cat tests/output/$f >> log
      printf "\n\n" >> log
      echo "expected" >> log
      cat tests/cases/$f >> log
      printf "\n\n" >> log
      echo "diff" >> log
      diff <(cat tests/cases/$f) <(cat tests/output/$f) >> log
      printf "\n\n" >> log
  fi

done)|column -t

