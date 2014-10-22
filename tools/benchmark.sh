#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

dartDir=$(which dart)

mkdir -p "inferred/"
mkdir -p ".stripped/"

if [ ! -f benchmarks/results.info ]; then
    printf "var results = [\n];" > benchmarks/results.info
fi

benchmarks=$(ls benchmarks)
if [ $# -ne 0 ]; then
    benchmarks=$*
fi

for benchmark in $benchmarks; do
    if [ -d benchmarks/$benchmark ]; then

        echo "Working on " $benchmark

        #If the test is completely new, copy an initial copy to stripped cache
        if [ ! -d .stripped/$benchmark ]; then
            cp -r benchmarks/$benchmark .stripped/        
            touch benchmarks/$benchmark
        fi

        #Prepare stripped
        entryfile=($(grep ^$benchmark benchmarks/entryfiles.info))
        entryfile=${entryfile[1]}

        if [ benchmarks/$benchmark -nt .stripped/$benchmark ]; then

            dart tools/dependency.dart --dart-sdk ${dartDir%bin/dart} .stripped/$benchmark/$entryfile

            for  f in $(dart tools/dependency.dart --dart-sdk ${dartDir%bin/dart} .stripped/$benchmark/$entryfile); do
                echo $f
                strip.dart -w $f
                wc -l $f
            done
        fi
        
        echo "Strip done"

        #Prepare benchmark to run on
        rm -rf inferred/$benchmark
        cp -r .stripped/$benchmark inferred

        dart --old_gen_heap_size=1000m bin/analyze.dart -w --actual-basedir inferred --expected-basedir benchmarks --dart-sdk ${dartDir%bin/dart} inferred/$benchmark/$entryfile > tmp
        
        #date=$(date -j -f "%a %b %d %T %Z %Y" "`date`" "+%s")

    fi
done

    

exit


for benchmark in $(ls benchmarks); do


    if [ ! -d .stripped/$benchmark ]; then
        cp -r benchmarks/$benchmark .stripped/        
    fi
    
    for file in $(find .stripped/$benchmark -name "*.dart"); do
        strip.dart $file > tmp
        rm $file
        mv tmp $file
    done

    rm -rf inferred/$benchmark
    cp -r .stripped/$benchmark inferred/

    dart --old_gen_heap_size=1000m bin/analyze.dart -w --actual-basedir .inferred/$benchmark --expected-basedir benchmarks/$benchmark --dart-sdk ${dartDir%bin/dart} ./tests/output/tests.dart 

done


<<<<<<< HEAD
  cp -r benchmarks/$benchmark inferred/
  cd "inferred/$benchmark"
=======
if [ $# -eq 0 ]; then
  (for benchmark in $(ls ./benchmarks/)
  do
    cp -r benchmarks/$benchmark inferred/
    cd "inferred/$benchmark"
>>>>>>> 03153084c42ef83e2ee01f16b5c51bc8e5c58c26

    
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

<<<<<<< HEAD

=======
    dartDir=$(which dart)
>>>>>>> 03153084c42ef83e2ee01f16b5c51bc8e5c58c26

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


