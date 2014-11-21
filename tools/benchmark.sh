#!/bin/bash

cd "`dirname \"$0\"`"
cd ".."

dartDir=$(which dart)

mkdir -p "inferred/"
mkdir -p ".stripped/"

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
            cp -a benchmarks/$benchmark .stripped/ 

            cd .stripped/$benchmark
            pub get
            cd ../..
            
            doStrip=1
        fi

        #Prepare stripped
        entryfile=($(grep ^$benchmark benchmarks/benchmarks.info))
        
        if [ ! $? -eq 0 ]; then
            echo "Couldnt find entry file, skipping"
        else
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
            cp -a .stripped/$benchmark inferred

            cd inferred/$benchmark
            pub get
            cd ../..

            start=$(php -r 'echo microtime(TRUE);')

            dart --old_gen_heap_size=2000m bin/analyze.dart -w --skip-sdk --skip-packages --actual-basedir inferred --expected-basedir benchmarks --dart-sdk ${dartDir%bin/dart} inferred/$benchmark/$entryfile

            end=$(php -r 'echo microtime(TRUE);')

            IFS='.';
            start=($start)
            end=($end)
            delta[0]=$((10#${end[0]}-10#${start[0]}))
            delta[1]=$((10#${end[1]}-10#${start[1]}))
            ms=$((${delta[0]}*1000+${delta[1]}/10))
            printf ".. in %s ms!\n" $ms
            unset IFS
        fi
    fi
done
