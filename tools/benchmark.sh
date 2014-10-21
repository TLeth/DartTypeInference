#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

mkdir -p "inferred/"

if [ $# -eq 0 ]; then
  (for benchmark in $(ls ./benchmarks/)
  do
    cp -r benchmarks/$benchmark inferred/
    cd "inferred/$benchmark"

    
    type_mismatch=0
    generic_misses=0
    generic_mismatch=0

    for file in $(cat ./files.info)
    do
        strip.dart $file > tmp;
        rm $file
        mv tmp $file

        echo $file
        total=$(../../tools/types.dart ../../benchmarks/$benchmark/$file $file)
        res=($total)
        type_mismatch=$((type_mismatch + res[0]))
        generic_misses=$((generic_misses + res[1]))
        generic_mismatch=$((generic_mismatch + res[2]))
  #      total=$((total+$(diff -U 0 <(dartfmt $file) <(dartfmt ../../benchmarks/$benchmark/$file) | grep ^+ | sed "1d" | wc -l)))
    done

    dartDir=$(which dart)

    dart "../../bin/analyze.dart" --dart-sdk ${dartDir%bin/dart} -w $(head -n 1 ./files.info)

    type_mismatch_diffs=0
    generic_misses_diffs=0
    generic_mismatch_diffs=0

    for file in $(cat ./files.info)
    do
        echo $file
        total_diffs=$(../../tools/types.dart ../../benchmarks/$benchmark/$file $file)
        res=($total_diffs)
        type_mismatch_diffs=$((type_mismatch_diffs + res[0]))
        generic_misses_diffs=$((generic_misses_diffs + res[1]))
        generic_mismatch_diffs=$((generic_mismatch_diffs + res[2]))
    done

    echo $benchmark
    echo Type mismatch: $type_mismatch Generic misses: $generic_misses Generic mismatch $generic_mismatch
    echo Type mismatch: $type_mismatch_diffs Generic misses: $generic_misses_diffs Generic mismatch $generic_mismatch_diffs
    
    cd ../..
  done)
else
  (for arg in $*; do
    (for benchmark in $(ls ./benchmarks/)
    do
      if [ "$arg" == "$benchmark" ]; then
        cp -r benchmarks/$benchmark inferred/
        cd "inferred/$benchmark"

        
        type_mismatch=0
        generic_misses=0
        generic_mismatch=0

        for file in $(cat ./files.info)
        do
            strip.dart $file > tmp;
            rm $file
            mv tmp $file

            echo $file
            total=$(../../tools/types.dart ../../benchmarks/$benchmark/$file $file)
            res=($total)
            type_mismatch=$((type_mismatch + res[0]))
            generic_misses=$((generic_misses + res[1]))
            generic_mismatch=$((generic_mismatch + res[2]))
        #      total=$((total+$(diff -U 0 <(dartfmt $file) <(dartfmt ../../benchmarks/$benchmark/$file) | grep ^+ | sed "1d" | wc -l)))
        done

        dartDir=$(which dart)

        dart "../../bin/analyze.dart" --dart-sdk ${dartDir%bin/dart} -w $(head -n 1 ./files.info)

        type_mismatch_diffs=0
        generic_misses_diffs=0
        generic_mismatch_diffs=0

        for file in $(cat ./files.info)
        do
            echo $file
            total_diffs=$(../../tools/types.dart ../../benchmarks/$benchmark/$file $file)
            res=($total_diffs)
            type_mismatch_diffs=$((type_mismatch_diffs + res[0]))
            generic_misses_diffs=$((generic_misses_diffs + res[1]))
            generic_mismatch_diffs=$((generic_mismatch_diffs + res[2]))
        done

        echo $benchmark
        echo Type mismatch: $type_mismatch Generic misses: $generic_misses Generic mismatch $generic_mismatch
        echo Type mismatch: $type_mismatch_diffs Generic misses: $generic_misses_diffs Generic mismatch $generic_mismatch_diffs
        
        cd ../..
      fi
    done)
  done)
fi

#rm -r inferred/
