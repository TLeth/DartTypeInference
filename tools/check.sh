#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

dartDir=$(which dart)
rm -f log

cp -r tests/ tests_stripped

for f in $(ls tests_stripped/)
do
    echo -ne $f'                  \r'
    strip.dart tests_stripped/$f > tmp.dart
    mv tmp.dart tests_stripped/$f
done

dart ./bin/analyze.dart --dart-sdk ${dartDir%bin/dart} tests_stripped/tests.dart

(for f in $(ls tests/)
do
  dartfmt -w tests_stripped/$f

  if [ $(diff <(cat tests/$f) <(cat tests_stripped/$f) | wc -l) -eq 0 ]
  then echo -e $f '\033[0;32mPass\033[0m'
  else 
      echo -e $f '\033[0;31mFail\033[0m'
      echo $f >> log
      echo "------------------------------" >> log
      echo "got" >> log
      cat tests_stripped/$f >> log
      printf "\n\n" >> log
      echo "expected" >> log
      cat tests/$f >> log
      printf "\n\n" >> log
      echo "diff" >> log
      diff <(cat tests/$f) <(cat tests_stripped/$f) >> log
      printf "\n\n" >> log
  fi

done)|column -t

rm -r tests_stripped
