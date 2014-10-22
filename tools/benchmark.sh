#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

dartDir=$(which dart)

mkdir -p "inferred/"
mkdir -p ".stripped/"

if [ ! -f benchmarks/results.json ]; then
    printf "var results = [\n];" > benchmarks/results.json
fi

benchmarks=$(ls benchmarks)
if [ $# -ne 0 ]; then
    benchmarks=$*
fi

for benchmark in $benchmarks; do
    if [ -d benchmarks/$benchmark ]; then

        echo "Working on " $benchmark
        doStrip=0
        #If the test is completely new, copy an initial copy to stripped cache
        if [ ! -d .stripped/$benchmark -o benchmarks/$benchmark -nt .stripped/$benchmark ]; then
            echo "Benchmark has changed - making new cache"
            rm -rf .stripped/$benchmark
            cp -r benchmarks/$benchmark .stripped/ 

            cd .stripped/$benchmark
            pub get
            cd ../..
            
            doStrip=1
        fi

        #Prepare stripped
        entryfile=($(grep ^$benchmark benchmarks/entryfiles.info))
        entryfile=${entryfile[1]}

        if [ ! $doStrip -eq 0 ]; then
            echo "Stripping..."

            for  f in $(dart tools/dependency.dart --dart-sdk ${dartDir%bin/dart} .stripped/$benchmark/$entryfile); do
                echo -e -n "$f\r"
                strip.dart -w $f
            done
            echo "Strip done"
            
        else
            echo "Using cache"
        fi
        


        #Prepare benchmark to run on
        rm -rf inferred/$benchmark
        cp -r .stripped/$benchmark inferred

        dart --old_gen_heap_size=1000m bin/analyze.dart -w --actual-basedir inferred --expected-basedir benchmarks --dart-sdk ${dartDir%bin/dart} inferred/$benchmark/$entryfile

    fi
done
