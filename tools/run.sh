#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

mkdir -p "inferred/"

(for benchmark in $(ls ./benchmarks/)
do
  cp -r benchmarks/$benchmark inferred/
  cd "inferred/$benchmark"

  total=0

  for file in $(cat ./files.info)
  do

      strip.dart $file > tmp;
      rm $file
      mv tmp $file

      #diff -U 0 <(dartfmt $file) <(dartfmt ../../benchmarks/$benchmark/$file) | grep ^[+-]

      total=$((total+$(diff -U 0 <(dartfmt $file) <(dartfmt ../../benchmarks/$benchmark/$file) | grep ^+ | sed "1d" | wc -l)))
  done
    
  dartDir=$(which dart)
  dart "../../bin/analyze.dart" --dart-sdk ${dartDir%bin/dart} $(head -n 1 ./files.info)




  cd "../.."

  
  
  


done)

